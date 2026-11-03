# 服务器部署验收清单

> 用途：在服务器上部署 AI 简历服务端后，按序执行验收。勾选项通过后即可交付用户使用。
> 部署步骤见 [DEPLOYMENT.md](DEPLOYMENT.md)；背景见 [HANDOVER.md](HANDOVER.md)。
> 配套远程验收：把服务地址（如 `http://<IP>:8000`）发给开发侧即可自动复跑第 3-6 节。

## 1. 部署（服务器上执行）

```bash
# —— 方式一:服务器直接构建(推荐,服务器可联网时) ——
git clone <仓库地址> ai-resume && cd ai-resume
# 构建 Linux 发行包(需要 Python 3.11+ 与 Node 18+):
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && cd ..
cd client && npm ci && npm run build && cd ..
backend/scripts/build_release.sh
# 产物: dist-release/ai-resume-server-linux-x86_64-lite.tar.gz (+ SHA256SUMS)

# —— 方式二:本地构建后上传(离线服务器) ——
# 在构建机执行 build_release.sh,把 tar.gz 与 SHA256SUMS scp 上服务器

# 解压安装:
tar -xzf ai-resume-server-linux-x86_64-lite.tar.gz && cd ai-resume-server-linux-x86_64-lite
cp .env.example .env && vi .env     # 必改: ADMIN_PASSWORD;按需: LLM_API_URL/KEY/MODEL、AUTH_MODE
sudo ./deploy/install.sh            # systemd 安装(默认 /opt/ai-resume,端口 8000)
```

> 防火墙放行 8000（或反代 443）。公网部署保持 `AUTH_MODE=required`。

## 2. 服务健康（服务器上）

- [ ] `sudo systemctl status ai-resume` → active (running)
- [ ] `curl -s http://127.0.0.1:8000/api/health` → `"ok":true`
- [ ] `journalctl -u ai-resume -n 50 --no-pager` 无 ERROR/Traceback

## 3. 用户核心链路（浏览器）

打开 `http://<服务器IP>:8000/`：

- [ ] **注册**：注册页创建测试账号（如 `acceptest1` / `Accept1234`），自动登录跳转
- [ ] **简历编辑**：填姓名/学校等字段 → 修改后刷新页面数据仍在（自动保存）
- [ ] **档案管理**：工具栏"另存为新档案"→ 建第 2 份档案并改名 → 切换回"默认档案"内容正确隔离
- [ ] **AI 生成**：智能体页 → 生成结构化简历 → 有结果（配置了模型则 provider=llm，未配置显示回退提示）→ "应用到编辑器"成功
- [ ] **导出 Word**：预览区"导出Word"下载 .docx 可打开
- [ ] **导出 PDF**：预览区"导出PDF"下载 .pdf 文字可选中（浏览器端渲染）
- [ ] **退出登录 / 重登**：数据仍在（云端档案）

## 4. 手机端连通（可选，App 上线后）

手机安装 App →「我的 → 账号与设置」→ 服务端地址填 `http://<服务器IP>:8000`：

- [ ] 连接状态行变"服务端已连接"
- [ ] 注册/登录成功 → 编辑简历 → 云端档案同步（网页端能看到 App 建的档案）

## 5. 运营侧（admin）

- [ ] admin 登录 → 右上角菜单出现"运营后台"
- [ ] 概览统计出现刚才的注册/生成记录
- [ ] 用户管理可见 acceptest1；禁用后该账号立即 401、启用恢复
- [ ] 审计日志有完整事件流

## 6. 安全基线

- [ ] `.env` 中 `ADMIN_PASSWORD` 已改为强口令（不是示例值）
- [ ] `AUTH_MODE=required`（公网）
- [ ] LLM API Key 只存在于服务端（.env 或在线配置），未出现在任何前端/仓库文件
- [ ] `data/` 目录已纳入备份计划（见 HANDOVER §3）

## 7. 远程验收（开发侧自动化）

提供信息后由开发侧复跑：服务地址 +（可选）admin 测试账号。
覆盖：健康检查、注册/登录回环、档案 CRUD 与隔离、生成链路、导出、统计与审计。
