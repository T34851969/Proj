#!/usr/bin/env bash
# AI Resume Server — .deb 打包(输入: build_release.sh --stage 的布局)
# 仅依赖 dpkg-deb(本机不需要 debian 环境);包内容自包含,目标机零依赖。
# 安装行为:enable 不 start(用户规则);启动: systemctl enable --now ai-resume
set -euo pipefail

usage() {
  cat <<EOF
用法: $0 --layout DIR --version X.Y.Z [--out DIR] [--maintainer "Name <email>"]
  --layout      build_release.sh --stage 直出的布局目录(含 app/runtime/data/deploy)
  --version     包版本号
  --out         输出目录(默认 ./dist-release)
EOF
  exit 1
}

LAYOUT="" VER="" OUT="./dist-release" MAINTAINER="T34851969 <T34851969@users.noreply.github.com>"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout) LAYOUT="$2"; shift 2 ;;
    --version) VER="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --maintainer) MAINTAINER="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; usage ;;
  esac
done
[ -n "$LAYOUT" ] && [ -n "$VER" ] || usage
[ -f "$LAYOUT/app/main.py" ] && [ -x "$LAYOUT/runtime/bin/python" ] || { echo "布局不完整: $LAYOUT" >&2; exit 1; }

PKGROOT="$(mktemp -d)/ai-resume-server_${VER}-amd64"
mkdir -p "$PKGROOT/DEBIAN" "$PKGROOT/opt" "$PKGROOT/usr/lib/systemd/system"
echo "== 装载布局 → /opt/ai-resume =="
cp -rT "$LAYOUT" "$PKGROOT/opt/ai-resume"
# conffile:.env 不存在则从模板生成
[ -f "$PKGROOT/opt/ai-resume/.env" ] || cp "$PKGROOT/opt/ai-resume/.env.example" "$PKGROOT/opt/ai-resume/.env"

echo "== 生成 systemd unit =="
sed -e 's|{{SERVICE_USER}}|ai-resume|g' \
    -e 's|{{INSTALL_DIR}}|/opt/ai-resume|g' \
    -e 's|{{BIND_HOST}}|0.0.0.0|g' \
    -e 's|{{PORT}}|8000|g' \
    "$LAYOUT/deploy/ai-resume.service.template" \
    > "$PKGROOT/usr/lib/systemd/system/ai-resume.service"

cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: ai-resume-server
Version: $VER
Architecture: amd64
Maintainer: $MAINTAINER
Description: AI Resume Server (FastAPI, self-contained)
 AI 简历生成器后端:内嵌 Python 运行时与全部依赖,
 单机零安装部署,Web 端口 8000,systemd 管理(ai-resume.service)。
EOF
echo "/opt/ai-resume/.env" > "$PKGROOT/DEBIAN/conffiles"

cat > "$PKGROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  getent passwd ai-resume >/dev/null 2>&1 || \
    useradd -r -s /usr/sbin/nologin -d /opt/ai-resume ai-resume
  chown -R ai-resume:ai-resume /opt/ai-resume
  systemctl daemon-reload || true
  # 规则:只 enable 不 start;启动由管理员执行 systemctl enable --now ai-resume
  systemctl enable ai-resume.service || true
  echo "ai-resume-server: 已 enable(未启动)。启动: systemctl enable --now ai-resume"
fi
EOF
cat > "$PKGROOT/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
# 升级/卸载前停服(运行中替换文件不安全)
if [ -d /run/systemd/system ]; then
  systemctl stop ai-resume.service 2>/dev/null || true
fi
EOF
cat > "$PKGROOT/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
EOF
chmod 755 "$PKGROOT/DEBIAN/postinst" "$PKGROOT/DEBIAN/prerm" "$PKGROOT/DEBIAN/postrm"
chmod 644 "$PKGROOT/DEBIAN/control" "$PKGROOT/DEBIAN/conffiles"

mkdir -p "$OUT"
echo "== dpkg-deb --build =="
dpkg-deb --build --root-owner-group "$PKGROOT" "$OUT/ai-resume-server_${VER}-amd64.deb"
echo "== 完成 =="
ls -lh "$OUT/ai-resume-server_${VER}-amd64.deb"
dpkg-deb -I "$OUT/ai-resume-server_${VER}-amd64.deb" | head -8
