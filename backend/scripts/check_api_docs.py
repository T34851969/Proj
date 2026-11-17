#!/usr/bin/env python3
"""Fail the build when the HTTP contract drifts away from API.md.

Run from the repository root:

    backend/.venv/bin/python backend/scripts/check_api_docs.py

Checks, in order:

A. Route parity — the set of (method, path) served by the FastAPI app must be
   exactly the set listed in API.md §1. Both directions are enforced: a new
   route without a doc entry fails, and a doc entry for a route that no longer
   exists fails too (stale documentation is as harmful as missing docs).

B. Response models — every ``response_model`` used by a route must be named
   somewhere in API.md, so a renamed model cannot silently go undocumented.

C. Schema field parity — every Pydantic model that API.md declares as a
   TypeScript interface in 附录 A must have exactly the same field names on
   both sides (order-independent, nullability-independent).

D. Coverage — every Pydantic model in ``app/models/schemas.py`` must either be
   declared as a TS interface in API.md, or be listed in ``TABLE_DOCUMENTED``
   below with the section that documents it field-by-field as a markdown table.
   Adding a model therefore forces a conscious decision instead of a silent
   gap. For allowlisted models the field names must still appear in API.md.

E. Pinned-dependency parity — ``requirements-contract.txt`` (the minimal set CI
   installs to run this script) must pin the same versions as
   ``requirements.txt`` for every package it lists. Otherwise the CI check
   silently runs against different library versions than production.

Exit code 0 = in sync, 1 = drift (with a per-item report on stdout).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

API_MD = ROOT / "API.md"
REQ_FULL = ROOT / "backend" / "requirements.txt"
REQ_CONTRACT = ROOT / "backend" / "requirements-contract.txt"

# Models documented as markdown tables instead of TS interfaces (request bodies
# that read better as a field/constraint table). Keep this list in sync by hand;
# check D fails if a new model appears in schemas.py and is in neither place.
TABLE_DOCUMENTED = {
    "RegisterRequest": "§3",
    "LoginRequest": "§3",
    "ChangePasswordRequest": "§3",
    "ProfileCreateRequest": "§7",
    "ProfileUpdateRequest": "§7",
    "KnowledgeDocumentCreate": "§8",
    "LlmConfigUpdate": "§11",
    "LlmTestRequest": "§11",
    "UserStatusUpdate": "§12",
    "ResetPasswordRequest": "§12",
}


# ---------------------------------------------------------------------------
# Live contract
# ---------------------------------------------------------------------------

def collect_routes() -> set[tuple[str, str]]:
    """(METHOD, canonical_path) for every route the app actually serves."""
    from fastapi.routing import APIRoute

    from app.main import app

    routes: set[tuple[str, str]] = set()
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        for method in route.methods:
            if method in ("HEAD", "OPTIONS"):
                continue
            routes.add((method, canonical_path(route.path)))
    return routes


def collect_response_models() -> set[str]:
    """Names of every model referenced as a route response_model."""
    from fastapi.routing import APIRoute

    from app.main import app

    names: set[str] = set()
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        model = route.response_model
        if model is None:
            continue
        for arg in getattr(model, "__args__", ()):
            names.add(getattr(arg, "__name__", str(arg)))
        names.add(getattr(model, "__name__", str(model)))
    return {n for n in names if n and n != "NoneType"}


def collect_schemas() -> dict[str, set[str]]:
    """Every Pydantic model in schemas.py → its declared field names."""
    import inspect

    from pydantic import BaseModel

    from app.models import schemas

    out: dict[str, set[str]] = {}
    for name, obj in vars(schemas).items():
        if not inspect.isclass(obj) or not issubclass(obj, BaseModel) or obj is BaseModel:
            continue
        if obj.__module__ != schemas.__name__:
            continue
        out[name] = set(obj.model_fields)
    return out


def pinned_versions(path: Path) -> dict[str, str]:
    """``package==1.2.3`` lines → {package: version}; comments/blanks ignored."""
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or "==" not in line:
            continue
        name, _, version = line.partition("==")
        out[name.strip().lower()] = version.strip()
    return out


def canonical_path(path: str) -> str:
    """``/api/profiles/{profile_id}`` → ``/api/profiles/{}``.

    Parameter *names* are deliberately not compared: they are not part of the
    wire format, and API.md uses shorter names (``{id}``) for readability.
    """
    return re.sub(r"\{[^}]*\}", "{}", path)


# ---------------------------------------------------------------------------
# Documented contract
# ---------------------------------------------------------------------------

def documented_routes(md: str) -> set[tuple[str, str]]:
    """Parse the §1 接口总览 table: ``| METHOD | `path` | permission | note |``."""
    section = section_text(md, "## 1. 接口总览")
    routes: set[tuple[str, str]] = set()
    for line in section.splitlines():
        m = re.match(r"\|\s*(GET|POST|PUT|PATCH|DELETE)\s*\|\s*`([^`]+)`", line)
        if m:
            routes.add((m.group(1), canonical_path(m.group(2).strip())))
    return routes


def documented_interfaces(md: str) -> dict[str, set[str]]:
    """Parse 附录 A: ``interface Name { field: type; ... }`` → field name sets.

    Handles single-line and multi-line bodies, ``extends`` clauses, trailing
    ``//`` comments, and inline object generics (``Array<{ day: string }>``,
    whose nested keys must not be attributed to the enclosing interface).
    """
    section = section_text(md, "## 附录 A 数据模型")
    # Strip line comments first: they may precede a field on the same line.
    section = re.sub(r"//[^\n]*", "", section)

    own: dict[str, set[str]] = {}
    parents: dict[str, str] = {}
    for m in re.finditer(r"^interface (\w+)(?:\s+extends\s+(\w+))?\s*\{", section, re.M):
        name, parent = m.group(1), m.group(2)
        if parent:
            parents[name] = parent
        body = _brace_body(section, m.end() - 1)
        # Drop inline generics so nested object keys do not leak upward.
        body = re.sub(r"<[^<>]*>", "", body)
        fields: set[str] = set()
        for chunk in body.split(";"):
            fm = re.match(r"\s*(\w+)\??\s*:", chunk)
            if fm:
                fields.add(fm.group(1))
        own[name] = fields

    # Flatten `extends`: ProfileDetail extends ProfileMeta must inherit its fields.
    out: dict[str, set[str]] = {}
    for name, fields in own.items():
        merged = set(fields)
        seen = {name}
        parent = parents.get(name)
        while parent and parent not in seen and parent in own:
            seen.add(parent)
            merged |= own[parent]
            parent = parents.get(parent)
        out[name] = merged
    return out


def _brace_body(text: str, open_index: int) -> str:
    """Return the text between the brace at ``open_index`` and its match."""
    depth = 0
    for i in range(open_index, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1 : i]
    raise SystemExit("API.md 附录 A 存在未闭合的 interface 大括号")


def section_text(md: str, heading: str) -> str:
    """Text of one ``## `` section (up to the next ``## ``)."""
    start = md.find(heading)
    if start < 0:
        raise SystemExit(f"API.md 缺少章节：{heading!r}")
    rest = md[start + len(heading):]
    nxt = re.search(r"^## ", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def main() -> int:
    if not API_MD.exists():
        print(f"FAIL: {API_MD} 不存在")
        return 1
    md = API_MD.read_text(encoding="utf-8")

    problems: list[str] = []

    # A. route parity
    live_routes = collect_routes()
    doc_routes = documented_routes(md)
    for method, path in sorted(live_routes - doc_routes):
        problems.append(f"[A] 路由未写进 API.md §1：{method} {path}")
    for method, path in sorted(doc_routes - live_routes):
        problems.append(f"[A] API.md §1 记录了不存在的路由：{method} {path}")

    # B. response models (builtin container wrappers carry no information)
    for name in sorted(collect_response_models() - {"list", "dict", "NoneType"}):
        if not re.search(rf"\b{re.escape(name)}\b", md):
            problems.append(f"[B] response_model 未在 API.md 出现：{name}")

    # C. field parity for documented interfaces
    interfaces = documented_interfaces(md)
    schemas = collect_schemas()
    checked_models = 0
    for name, ts_fields in sorted(interfaces.items()):
        if name not in schemas:
            problems.append(f"[C] API.md 附录 A 声明了代码中不存在的模型：{name}")
            continue
        checked_models += 1
        py_fields = schemas[name]
        for f in sorted(py_fields - ts_fields):
            problems.append(f"[C] {name}.{f} 在代码中存在，但 API.md 附录 A 未声明")
        for f in sorted(ts_fields - py_fields):
            problems.append(f"[C] {name}.{f} 在 API.md 附录 A 中声明，但代码中不存在")

    # D. coverage of every model
    for name, py_fields in sorted(schemas.items()):
        if name in interfaces:
            continue
        if name in TABLE_DOCUMENTED:
            missing = [f for f in sorted(py_fields) if not re.search(rf"\b{re.escape(f)}\b", md)]
            if missing:
                problems.append(
                    f"[D] {name} 以表格形式记录于 API.md {TABLE_DOCUMENTED[name]}，"
                    f"但字段未出现：{', '.join(missing)}"
                )
            continue
        problems.append(
            f"[D] 模型 {name} 既未在 API.md 附录 A 声明为 TS interface，"
            f"也未登记进 check_api_docs.py 的 TABLE_DOCUMENTED"
        )

    # E. pinned dependency parity
    full_pins = pinned_versions(REQ_FULL)
    for pkg, version in sorted(pinned_versions(REQ_CONTRACT).items()):
        if pkg not in full_pins:
            problems.append(f"[E] requirements-contract.txt 的 {pkg} 不在 requirements.txt 中")
        elif full_pins[pkg] != version:
            problems.append(
                f"[E] {pkg} 版本不一致：requirements.txt={full_pins[pkg]} "
                f"vs requirements-contract.txt={version}"
            )

    print(
        f"契约检查：路由 {len(live_routes)} 条 / 文档 {len(doc_routes)} 条 · "
        f"TS interface {len(interfaces)} 个（逐字段核对 {checked_models} 个）· "
        f"Pydantic 模型 {len(schemas)} 个"
    )

    if problems:
        print(f"\n发现 {len(problems)} 处不一致：\n")
        for p in problems:
            print(f"  {p}")
        print(
            "\n怎么修：\n"
            "  [A] 改接口了 → 同步 API.md §1 接口总览 + 对应业务节\n"
            "  [B] 换了 response_model → 在 API.md 里提及该模型名\n"
            "  [C] 字段增删改名 → 同步 API.md 附录 A 的 TS interface\n"
            "  [D] 新增模型 → 附录 A 加 interface；若用表格描述则登记进 "
            "check_api_docs.py 的 TABLE_DOCUMENTED\n"
            "  [E] 改了依赖版本 → backend/requirements-contract.txt 同步同一个版本号"
        )
        return 1

    print("API.md 与实现一致。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
