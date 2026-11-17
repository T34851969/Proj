#!/usr/bin/env bash
# AI Resume Server — .rpm 打包(输入: build_release.sh --stage 的布局)
# 仅依赖 rpmbuild(本机不需要红帽环境);包内容自包含,目标机零依赖。
# 安装行为:enable 不 start(用户规则);启动: systemctl enable --now ai-resume
set -euo pipefail

usage() {
  cat <<EOF
用法: $0 --layout DIR --version X.Y.Z [--out DIR]
  --layout      build_release.sh --stage 直出的布局目录
  --version     包版本号
  --out         输出目录(默认 ./dist-release)
EOF
  exit 1
}

LAYOUT="" VER="" OUT="./dist-release"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout) LAYOUT="$2"; shift 2 ;;
    --version) VER="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; usage ;;
  esac
done
[ -n "$LAYOUT" ] && [ -n "$VER" ] || usage
[ -f "$LAYOUT/app/main.py" ] && [ -x "$LAYOUT/runtime/bin/python" ] || { echo "布局不完整: $LAYOUT" >&2; exit 1; }
command -v rpmbuild >/dev/null || { echo "缺少 rpmbuild(安装 rpm 包或 rpm-build 即可)" >&2; exit 1; }

LAYOUT="$(readlink -f "$LAYOUT")"
mkdir -p "$OUT"
TOP="$(mktemp -d)"
mkdir -p "$TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cat > "$TOP/SPECS/ai-resume-server.spec" <<EOF
Name:           ai-resume-server
Version:        $VER
Release:        1%{?dist}
Summary:        AI Resume Server (FastAPI, self-contained)
License:        Proprietary
BuildArch:      x86_64
AutoReqProv:    no
Requires:       systemd

%description
AI 简历生成器后端:内嵌 Python 运行时与全部依赖,单机零安装部署,
Web 端口 8000,systemd 管理(ai-resume.service)。安装后默认 enable 不启动,
启动请执行 systemctl enable --now ai-resume。

%install
mkdir -p %{buildroot}/opt %{buildroot}/usr/lib/systemd/system
cp -rT %{layoutdir} %{buildroot}/opt/ai-resume
[ -f %{buildroot}/opt/ai-resume/.env ] || \\
  cp %{buildroot}/opt/ai-resume/.env.example %{buildroot}/opt/ai-resume/.env
sed -e 's|{{SERVICE_USER}}|ai-resume|g' \\
    -e 's|{{INSTALL_DIR}}|/opt/ai-resume|g' \\
    -e 's|{{BIND_HOST}}|0.0.0.0|g' \\
    -e 's|{{PORT}}|8000|g' \\
    %{layoutdir}/deploy/ai-resume.service.template \\
    > %{buildroot}/usr/lib/systemd/system/ai-resume.service

%files
/opt/ai-resume
/usr/lib/systemd/system/ai-resume.service
%config(noreplace) /opt/ai-resume/.env

%post
getent passwd ai-resume >/dev/null 2>&1 || \\
  useradd -r -s /usr/sbin/nologin -d /opt/ai-resume ai-resume
chown -R ai-resume:ai-resume /opt/ai-resume
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl enable ai-resume.service || true
  echo "ai-resume-server: 已 enable(未启动)。启动: systemctl enable --now ai-resume"
fi

%preun
if [ "\$1" = 0 ] && [ -d /run/systemd/system ]; then
  systemctl stop ai-resume.service 2>/dev/null || true
  systemctl disable ai-resume.service 2>/dev/null || true
fi

%postun
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
EOF

echo "== rpmbuild -bb =="
rpmbuild -bb --define "_topdir $TOP" \
  --define "pkgver $VER" --define "layoutdir $LAYOUT" \
  "$TOP/SPECS/ai-resume-server.spec"

RPM="$(find "$TOP/RPMS" -name '*.rpm' | head -1)"
mv "$RPM" "$OUT/"
echo "== 完成 =="
ls -lh "$OUT/"$(basename "$RPM")
rpm -q --info -p "$OUT/$(basename "$RPM")" | head -6
