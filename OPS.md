# 运维手册（OPS）

> **读者**：接管服务端运维的工程师。本文只写事实与操作，不写历史。
> 历史决策见 [_archive/](_archive/)；接口明细以运行中的 `http://<host>:8000/docs`(Swagger) 为准。

## 1. 服务形态与端口

「AI 简历生成器」：学生填写个人信息 → LLM(DeepSeek/Qwen, OpenAI 兼容接口)生成结构化简历 → 在线预览/换模板 → 导出 PDF/Word。

| 端 | 技术 | 说明 |
| --- | --- | --- |
| 服务端 | Python 3.11+ / FastAPI / SQLite，单进程 | 端口 8000，同时托管 Web 前端静态页，**零外部依赖**（无 Redis/消息队列/独立 DB） |
| Web 前端 | Vue 3.5 + Ant Design Vue 4 + Pinia | 由服务端托管，浏览器直接访问即为完整产品 |
| Windows 桌面端 | Tauri 2 壳 + 内嵌后端运行时 | 安装包自带后端（约 120MB），双击即用，不依赖服务器 |
| Android 端 | Tauri 2 Android 壳（APK） | 连接远程服务器使用，账号与云端档案跨端同步；Linux 桌面壳仍为骨架 |

- **唯一进程**：`uvicorn app.main:app`，默认 `127.0.0.1:8000`（`HOST`/`PORT` 可改）。
- 浏览器访问 `http://<host>:8000/` = 前端；`/api/*` = 接口；`/docs` = Swagger。
- 桌面端不连服务器也能用（壳自动拉起本机后端，数据在用户本机）。
- **不要**在同一数据目录并发运行两个实例（SQLite 单写者）；**不要**使用 `--workers`——多进程会重复加载嵌入模型且与 SQLite 单写者语义不匹配。

## 2. 构建发行包

服务器路线 = **自包含发行包**（内嵌 Python 解释器与全部依赖，目标机零安装、零网络、零 Node）。

```bash
# 构建机一次性准备(需网络):
cd backend && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt && cd ..
cd client && npm ci && npm run build && cd ..      # 前端产物 client/dist

# 打包(lite 约 120MB,默认;--full 含向量检索约 500MB)
backend/scripts/build_release.sh
# 产出: dist-release/ai-resume-server-linux-x86_64-lite.tar.gz + SHA256SUMS
```

包结构：

```text
ai-resume-server-<平台>-<lite|full>/
├── runtime/          # 内嵌 Python(勿改动)
├── app/              # 后端服务(FastAPI)
├── static/           # 前端页面(由后端直接托管,单端口)
├── data/             # 种子数据;运行时生成的 kb.sqlite3 也在 data/ 下,升级时保留即可
├── deploy/           # 部署脚本
├── .env.example      # 配置模板
└── OPS.md            # 本文件
```

`lite` 与 `full` 的唯一区别：full 含向量语义检索（嵌入模型栈，约 +1.1GB）；lite 的 RAG 自动降级为关键词检索，其余功能完全一致。

deb/rpm 打包、客户端与桌面端打包见 [packaging/README.md](packaging/README.md)。

## 3. 安装

### 3.1 Linux（systemd，推荐）

```bash
tar -xzf ai-resume-server-linux-x86_64-*.tar.gz && cd ai-resume-server-linux-x86_64-*
cp .env.example .env && vi .env        # 关键: LLM_API_URL/KEY/MODEL、ADMIN_PASSWORD、AUTH_MODE
sudo ./deploy/install.sh               # systemd 安装(默认 /opt/ai-resume, 端口 8000, 0.0.0.0)
# 自定义: sudo PREFIX=/srv/ai PORT=8000 SERVICE_USER=ai-resume ./deploy/install.sh
# 无 systemd/调试: ./deploy/start.sh 前台运行
```

- 无 root 权限时 `install.sh` 自动降级为用户级安装（`~/.local/share/ai-resume`），用 `./deploy/start.sh` 前台启动（建议配合 tmux）。
- 常用：`sudo systemctl {status|restart|stop} ai-resume`、`journalctl -u ai-resume -f`、`./deploy/{status,stop,uninstall}.sh`（免 systemd 环境）。

### 3.2 Windows 服务端（staging 与离线包）

离线 zip 包：`Expand-Archive` → 编辑 `.env` → `cd deploy` → `powershell -ExecutionPolicy Bypass -File install.ps1`（注册计划任务并启动）；卸载 `powershell -File uninstall.ps1`。

staging 部署目标为维护者自托管的 Windows runner（`.github/workflows/deploy-windows.yml` 中标注的 `self-hosted` 标签），以计划任务方式托管服务、安装位 `C:\Program Files\ai-resume`、端口 8000。该 runner 由维护者持有，外部协作者无需也无法复现此环境，仅需知道发版后有这条手动点火流程：

```bash
# 发版后手动点火（CI 用 GITHUB_TOKEN 建的 release 不会自动触发部署——GitHub 防递归机制）
gh workflow run deploy-windows.yml -R T34851969/Proj --ref v<版本>
# 破坏性实验可直接指定 dev 分支验证
gh workflow run deploy-windows.yml -R T34851969/Proj --ref dev
```

流程：runner 构建 lite 包 → 覆盖 staging → 健康检查 →（release 事件时追加 NSIS 安装包真机验收：静默安装 → 注册表验证 → 静默卸载）。耗时约 14 分钟。

手工启停 staging：用 `Start-ScheduledTask` / `Stop-ScheduledTask` 操作该计划任务。

### 3.3 平台边界

linux 包在 x86_64 + glibc 2.31+ 的主流发行版（Debian 11+/Ubuntu 20.04+/RHEL 9+）可直接运行；其他架构/平台请用对应机器执行 `backend/scripts/build_release.sh`（或 Windows 的 `build_release.ps1`）在本平台构建，流程完全一致。

## 4. 升级与回滚

```bash
# 升级(保留 data/ 与 .env):
sudo systemctl stop ai-resume
sudo cp -a /opt/ai-resume/data /backup/data-$(date +%F)      # 先备份
sudo tar -xzf ai-resume-server-linux-x86_64-NEW.tar.gz -C /tmp/rel
sudo rsync -a --delete /tmp/rel/ai-resume-server-*/app/   /opt/ai-resume/app/
sudo rsync -a --delete /tmp/rel/ai-resume-server-*/static/ /opt/ai-resume/static/
sudo rsync -a          /tmp/rel/ai-resume-server-*/runtime/ /opt/ai-resume/runtime/   # 运行时仅大版本升级才需要
sudo systemctl start ai-resume && curl -s http://127.0.0.1:8000/api/health

# 回滚 = 把旧包的 app/ 与 static/ 换回去(data/ 不回滚即保留新数据;库结构向后兼容)
```

等价说法：升级 = 备份 `data/` → 解压新包覆盖 → 还原 `data/` 与 `.env` → 重启服务。

## 5. 上线验收（按序勾选）

```bash
sudo systemctl status ai-resume                 # 服务 active
curl -s http://127.0.0.1:8000/api/health        # {"ok":true,...,"provider":"local-fallback" 或 "llm-configured"}
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/   # 200(Web 界面)
journalctl -u ai-resume -n 50 --no-pager        # 无 ERROR
```

**服务健康（服务器上）**

- [ ] `sudo systemctl status ai-resume` → active (running)
- [ ] `curl -s http://127.0.0.1:8000/api/health` → `"ok":true`
- [ ] `journalctl -u ai-resume -n 50 --no-pager` 无 ERROR/Traceback

**首次上线（浏览器，`http://<服务器IP>:8000/`）**

1. 注册/登录页 → 用 `.env` 的 `ADMIN_USERNAME/ADMIN_PASSWORD` 登录运营者。
2. **立即在运营后台 → 修改我的密码**（或至少确认 ADMIN_PASSWORD 已是强口令）。
3. 智能体页 →「模型服务」→ 填 API URL/Key/模型 → **测试连接** → 保存（即时生效，`/api/health` 的 `provider` 应变 `llm-configured`）。
4. 生成一次简历验证端到端。
5. 公网部署确认：`AUTH_MODE=required`（默认）、防火墙只放行 8000（或反代 443）。

**用户核心链路**

- [ ] **注册**：注册页创建测试账号（如 `acceptest1` / `Accept1234`），自动登录跳转
- [ ] **简历编辑**：填姓名/学校等字段 → 修改后刷新页面数据仍在（自动保存）
- [ ] **档案管理**：工具栏"另存为新档案"→ 建第 2 份档案并改名 → 切换回"默认档案"内容正确隔离
- [ ] **AI 生成**：智能体页 → 生成结构化简历 → 有结果（配置了模型则 provider=llm，未配置显示回退提示）→ "应用到编辑器"成功
- [ ] **导出 Word**：预览区"导出Word"下载 .docx 可打开
- [ ] **导出 PDF**：预览区"导出PDF"下载 .pdf 文字可选中（浏览器端渲染）
- [ ] **退出登录 / 重登**：数据仍在（云端档案）

**手机端连通（可选，App 上线后）**：手机安装 App →「我的 → 账号与设置」→ 服务端地址填 `http://<服务器IP>:8000`

- [ ] 连接状态行变"服务端已连接"
- [ ] 注册/登录成功 → 编辑简历 → 云端档案同步（网页端能看到 App 建的档案）

**运营侧（admin）**

- [ ] admin 登录 → 右上角菜单出现"运营后台"
- [ ] 概览统计出现刚才的注册/生成记录
- [ ] 用户管理可见 acceptest1；禁用后该账号立即 401、启用恢复
- [ ] 审计日志有完整事件流

**远程验收（开发侧自动化）**：把服务地址（如 `http://<IP>:8000`）发给开发侧即可复跑上述链路——覆盖健康检查、注册/登录回环、档案 CRUD 与隔离、生成链路、导出、统计与审计。

## 6. 数据目录与配置

### 6.1 数据目录（最重要）

所有状态都在**一个目录**：`DATA_DIR`（默认 `<发行包根>/data`，可用环境变量 `DATA_DIR` 覆盖）。

| 文件 | 内容 | 丢失后果 |
| --- | --- | --- |
| `auth.sqlite3` | 用户、登录令牌 | 全部账号不可登录（需重建） |
| `profiles.sqlite3` | 各用户的简历档案（云端档案） | 用户云端简历丢失（本机档案仍在客户端） |
| `kb.sqlite3` | 知识库文档/向量/检索配置 | 知识库需重新导入 |
| `runtime.sqlite3` | LLM 在线配置覆盖层 | 回退到 .env 配置 |
| `usage.sqlite3` | 使用统计与审计日志 | 统计/审计清零（不影响业务） |
| `prompt-templates.json` | 5 套提示词模板 | 生成功能不可用（可从仓库 `backend/data/` 恢复） |
| `templates.json` | 前端模板市场元数据 | 模板市场回退为随客户端内置列表 |

**备份**：优先停服后整目录拷贝；在线备份用 `sqlite3 <db> ".backup '<目标>'"` 逐库做（WAL 模式下直接 cp 主文件可能不一致）。`*-wal/-shm` 文件随主文件一起处理。

知识库数据在 `data/kb.sqlite3`（SQLite WAL，跨平台通用）；旧版 JSON 在启动时自动迁移。

### 6.2 配置（`.env`，发行包根目录）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `LLM_API_URL` / `LLM_API_KEY` / `LLM_MODEL` | 空 | OpenAI 兼容接口（chat/completions 完整 URL）。空=本地回退模式（模板拼装，无 AI）。支持 `OPENAI_*` 别名 |
| `AUTH_MODE` | `required` | `required`=必须登录；`optional`=允许匿名（桌面端用） |
| `REGISTRATION_MODE` / `INVITE_CODE` | open / 空 | 邀请码注册模式 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | admin / (env) | **仅首次启动**自动创建运营者账号；改这里不会改已有账号密码（用后台改密功能） |
| `ACCESS_CODE` | 空 | 旧版共享口令（迁移兼容，将移除） |
| `HOST` / `PORT` / `CORS_ORIGINS` / `DATA_DIR` | 127.0.0.1 / 8000 / 见下 / ./data | 监听与跨域；`CORS_ORIGINS` 默认含 `localhost:5173`、`127.0.0.1:5173`、`tauri.localhost`、`tauri://localhost` |
| `RATE_LIMIT_PER_MINUTE` | 30 | `/api/chat` 与 `/api/generate-resume` 的每 60 秒上限；`0`=关闭 |
| `CHAT_TEMPERATURE` | 0.7 | 上游采样温度 |
| `TOKEN_TTL_DAYS` | 7 | 令牌滑动有效期 |
| `LOCKOUT_THRESHOLD` / `LOCKOUT_MINUTES` | 5 / 15 | 登录失败锁定 |
| `LLM_TIMEOUT` / `CHAT_TIMEOUT` | 55 / 120 | 生成与对话的上游超时（秒） |
| `STATIC_DIR` | 空 | 前端产物目录；空则自动探测 `<包根>/static` 与 `<包根>/../client/dist` |

**LLM 配置优先级**：在线配置（runtime.sqlite3，运营者在界面「智能体→模型服务」保存）> .env。在线保存即时生效免重启。API Key 明文存本地 SQLite（与 .env 同级安全基线），接口永不回传明文。

## 7. 账号与权限

- 自助注册（用户名 4-32 位 `[A-Za-z0-9_-]`，密码 ≥8 位含字母数字）。令牌 7 天滑动过期；连续失败 5 次锁 15 分钟。
- 角色：`user`（普通）/ `admin`（运营者）。
- admin 专属：模型服务配置(`/api/llm-config*`)、运营后台(`/api/admin/*`：用户禁用/重置密码/统计/审计)、required 模式下的知识库写操作。
- 禁用账号即时生效（令牌解析层拒绝）。
- 运营后台入口：Web 登录 admin → 右上角用户菜单 →「运营后台」。

关键接口速查见 [API.md](API.md)；常用运维操作：

| 操作 | 做法 |
| --- | --- |
| 健康检查 | `curl -s http://127.0.0.1:8000/api/health` |
| 看日志 | systemd: `journalctl -u ai-resume -f`；前台: stdout |
| 改 LLM 配置 | 界面操作（admin → 模型服务 → 测试连接 → 保存），不要手改 runtime.sqlite3 |
| 重置用户密码 | 运营后台 → 用户管理 → 重置密码 |
| 换端口/对外监听 | 重跑 `install.sh` 传 `PORT`/`BIND_HOST`，或编辑 systemd unit 的 `ExecStart` 后 `daemon-reload`（`.env` 的 `HOST`/`PORT` 不影响监听——unit 用 CLI 参数绑定；`.env` 其余配置由 pydantic 从 WorkingDirectory 读入，改后重启生效） |
| 升级版本 | 见 §4（替换 app/ 与 static/，data/ 与 .env 不动） |

## 8. 故障排查

| 症状 | 排查 |
| --- | --- |
| 服务起不来 | `journalctl -u ai-resume -n 100`；确认 `runtime/bin/python` 可执行、`.env` 无语法错 |
| `ModuleNotFoundError: No module named 'fastapi'` | 虚拟环境未激活或依赖未安装：`python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt` |
| 前端提示「请求失败」/控制台 404 | 端口未对齐：后端实际端口看 `Uvicorn running on http://127.0.0.1:XXXX`，前端 `vite.config.ts` 的 `target` 需指向同一端口 |
| `/api/health` provider=local-fallback | LLM 未配置——界面「模型服务」保存(或 `.env` 后重启) |
| 生成报「LLM 未配置/超时」 | 模型服务里「测试连接」；检查 Key 有效期、URL 是 chat/completions 完整地址 |
| 大模型返回 401 | `LLM_API_KEY` 错误或过期 |
| 大模型返回 404 | `LLM_API_URL` 路径不完整，必须含 `/v1/chat/completions`（如 `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`） |
| LLM 调用失败但无错误提示 | 后端已捕获异常并输出 warning（`LLM call failed, falling back to local generation: ...`）并降级本地规则生成；检查 logging 级别是否被重置 |
| 401 遍地 | `AUTH_MODE=required` 下未登录/令牌过期属正常；检查是否误把 .env 改 optional 后又改回 |
| 429 | 触发限流（每用户每分钟上限），等一分钟 |
| SQLite busy/locked | 确认没有第二个实例共用同一 DATA_DIR |
| 端口被占/换端口 | 重跑 `install.sh PORT=新端口` 或改 unit 的 `ExecStart` 后 `daemon-reload`（`.env` 的 PORT 不影响 systemd 监听）；`ss -ltnp \| grep 8000` 查占用；桌面壳自身会自动换 8001+ |
| 桌面端红点离线 | 看 `%APPDATA%\com.airesume.app\backend-data\backend.log`；多为杀软拦截 python 或资源暂存不完整(重跑 prepare-backend.ps1 -Force) |
| 模板市场列表异常 | 检查 `data/templates.json` 格式(JSON 数组);损坏/缺失时客户端自动回退内置列表 |
| 生成报"服务端未配置模型接口" | 服务端未配 LLM 且用户未开自带 Key——运营后台「模型服务」配置,或让用户在「我的 → AI 模型」用自带 Key |
| Windows 中文乱码 | PowerShell 执行 `chcp 65001`，或在启动命令前加 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` |

## 9. 不变量与安全基线

**不变量（不要做）**

1. 不要删除/重置 `data/` 目录（用户数据全在里面）。
2. 不要手工编辑任何 `*.sqlite3`（用界面或 API）。
3. 不要长期 `AUTH_MODE=optional` 对公网（匿名可耗用生成接口；公网部署用 required + 邀请码）。
4. 不要绕过 `.env` 把 API Key 写进代码/前端（前端永远不应出现 Key）。
5. 升级前先备份 `data/`；回滚=换回旧 `app/` 目录即可（数据库结构向后兼容策略：`CREATE TABLE IF NOT EXISTS`，新增字段有默认值）。
6. LLM 生成走 `/generate-resume` 与 `/chat`，均有限流；上游模型超时默认 55s（`LLM_TIMEOUT`）。
7. 用户自带 Key(BYOK) 由后端当次转发、不落库（已内建）——运维侧同样不要把它写进日志或备份。

**安全基线**

- [ ] `.env` 中 `ADMIN_PASSWORD` 已改为强口令（不是示例值）
- [ ] `AUTH_MODE=required`（公网）；注册开放度用 `REGISTRATION_MODE=invite` + `INVITE_CODE` 控制
- [ ] LLM API Key 只存在于服务端（.env 或在线配置），未出现在任何前端/仓库文件
- [ ] `data/` 目录已纳入备份计划（见 §6.1）
- 建议前置 Nginx/Caddy 做 HTTPS；服务本身只监听内网时 `BIND_HOST=127.0.0.1`。

## 10. 测试基线

- 后端：`backend/.venv/Scripts|bin/python -m pytest`（当前 96 例全绿，含档案/运营后台/LLM 配置/鉴权）。
- 前端：`cd client && npm test`（16 例）+ `npm run build`（vue-tsc 类型门禁）。
- 桌面壳：`cd client && npx tauri build`（NSIS；产物 ~120MB 自包含）。
