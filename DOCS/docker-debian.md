# Docker 本地开发指南 — Debian / Ubuntu

适用系统：Debian、Ubuntu 及其衍生发行版。

## 概述

本指南介绍在 Debian/Ubuntu 系统上安装 Docker 引擎与 Compose 插件，并快速启动本项目的开发环境和常见排错要点。

## 安装 Docker（示例：Debian）

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

## 切换为非 root 用户运行 Docker（可选）

```bash
sudo usermod -aG docker $USER
# 重新登录或运行 `newgrp docker` 生效
```

## 启动项目（开发模式）

```bash
cp .env.example .env
docker compose up -d --build
```

访问：

- 健康检查: http://localhost:8000/health
- 示例路由: http://localhost:8000/api/v1/ping

## 常见问题与注意点（Debian / Ubuntu）

- APT 源与 GPG：若 `lsb_release -cs` 返回的发行代号未被 Docker 官方支持，请参考官方文档选择合适源或手动指定发行代号。
- systemd：某些精简发行或容器化环境可能没有 systemd，服务管理方式将有所不同。
- 权限：若需要 sudo 运行 docker，请将用户加入 `docker` 组或继续使用 sudo。

## 常用命令（Debian 环境）

```bash
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

# 清理磁盘空间（慎用）
docker system prune -af
```

## 生产镜像构建（本地测试）

```bash
docker build -t myorg/proj:latest .
# 运行本地镜像
docker run -p 8000:8000 --env-file .env myorg/proj:latest
```

## 数据持久化与备份

- 推荐使用 Docker 卷或宿主机路径挂载来持久化 PostgreSQL / MinIO 等数据。
- 备份数据库使用数据库自身备份工具（例如 `pg_dump`）。

更多通用说明与安全建议见项目根目录的 README.md 或 DOCS/docker-windows.md。
