"""Prompt templates + frontend resume-template distribution endpoints."""

import json

from fastapi import APIRouter

from app.config import settings
from app.models.schemas import PromptTemplate
from app.services.template_service import load_templates

router = APIRouter()


@router.get("/prompt-templates", response_model=list[PromptTemplate])
async def get_prompt_templates():
    return await load_templates()

# ---------------------------------------------------------------------------
# 前端简历模板元数据分发:运营者在服务器 data/templates.json 中增删改,
# 客户端模板市场即时同步(组件本身随客户端版本发布)。
# ---------------------------------------------------------------------------

@router.get("/templates")
async def list_resume_templates():
    path = settings.data_dir / "templates.json"
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []
