# Docker 本地开发指南 — Windows（Docker Desktop）

适用系统：Windows 10 / 11（推荐启用 WSL2 并在 WSL 内运行）。

## 概述

本指南覆盖在 Windows 上使用 Docker Desktop 运行本项目的步骤、常用命令与排错要点。推荐在 WSL2（Ubuntu / Debian 子系统）中操作以减少路径与权限问题。

## 安装与准备

1. 从 Docker 官方网站下载并安装 Docker Desktop。安装时勾选 WSL2 集成（若可用）。
2. 按提示重启系统（若需要）。
3. 启动 Docker Desktop，确认状态为 `Running`。

## 项目启动（开发模式）

在 PowerShell、CMD 或 WSL2 的终端中切换到项目根目录：

```powershell
# PowerShell 示例
Copy-Item .env.example .env
docker compose up --build
```

或在 WSL/bash：

```bash
cp .env.example .env
docker compose up --build
```

后台运行（daemonized）：

```bash
docker compose up -d --build
```

访问：

- 健康检查: http://localhost:8000/health
- 示例路由: http://localhost:8000/api/v1/ping

停止并移除容器：

```bash
docker compose down
```

## Windows 常见问题与注意点

- 卷挂载（volume）与文件权限：在 Windows 主机直接运行可能会遇到路径或权限错误，建议在 WSL2 环境中运行以避免这些问题。
- 虚拟化：若 Docker Desktop 无法启动，确认 BIOS/UEFI 中启用了虚拟化（VT-x/AMD-V）并启用 Hyper-V / WSL 功能。
- 文件共享与防病毒软件：某些防病毒或文件共享设置会阻止容器访问宿主路径，必要时在 Docker Desktop 设置中允许访问该目录。
- 资源限制：如构建或运行速度慢，可在 Docker Desktop 设置中增加 CPU / 内存分配。

## 常用命令（Windows 环境）

```bash
# 启动并构建（开发）
docker compose up --build

# 后台运行
docker compose up -d --build

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 进入容器（示例服务名为 web）
docker compose exec web /bin/sh

# 停止并移除容器
docker compose down
```

## 其他建议

- 将 `.env` 中的密钥仅保存在本地，且不要将其提交到仓库（确保 `.gitignore` 屏蔽）。
- 在 WSL2 中操作时，尽量使用 Linux 工具链（例如 `cp`、`bash`）以减少跨平台差异。

更多通用说明与生产建议见 DOCS/docker-debian.md 或根目录的 README.md。
