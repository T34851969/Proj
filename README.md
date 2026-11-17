# AI 简历生成器

基于大模型的学生个人简历撰写智能体。用户填写个人信息、选择模板，系统通过 LLM（DeepSeek/Qwen）自动生成排版精美的简历，支持 PDF/Word 导出。

> **文档导航**
> 运维（部署/升级/验收/排障/数据/配置） → [OPS.md](OPS.md) ·
> 工程约定 → [AGENTS.md](AGENTS.md) ·
> API 契约 → [backend-api.md](backend-api.md) / [frontend-api.md](frontend-api.md) ·
> 打包规范与构建 → [packaging/README.md](packaging/README.md) ·
> 历史归档 → [_archive/](_archive/)

## 项目背景

本项目是**学生项目实践**：由深圳技术大学学生团队在课程中协作完成，参与课程评审并计入学分，同时作为软件著作权申请的项目材料。项目派生自遵循 GPL 协议的既有开源项目，此后在账号体系、简历档案、运营后台与多端发行（Web / Windows / Linux / Android）上做了大幅重构。

课程报告与团队协作记录保留在 [_archive/](_archive/)，作为项目过程的留痕。

## 1. 功能

- **简历生成**：5 种提示词模板（简约校招、商务正式、创意亮点、技术研发、升学科研），LLM 自动生成文案；未配置模型时本地回退可用
- **模型双模式**：跟随服务器统一配置（需登录），或用户自带 Key（本机保存、服务端当次转发不落库）
- **简历档案**：一人多套简历（按岗位），一键切换；匿名存本机、登录后云端同步（多账号隔离）
- **RAG 知识库**：上传优秀简历文档，文本分块 + 向量/关键词检索（SQLite 存储），生成时注入相关上下文
- **模板服务端分发**：运营者修改服务器模板清单即时同步所有客户端的模板市场
- **在线预览**：网页内直接预览简历（5 套模板、分区拖拽排序、主题色/字号可调），PDF/Word 导出
- **AI 对话**：SSE 流式传输，Web Worker 处理，实时交互
- **账号体系**：自助注册/登录、令牌 7 天滑动过期、失败锁定；浅色/深色/跟随系统三态主题
- **运营后台**（admin）：模型服务在线配置（热生效免重启）、用户管理（禁用/重置密码）、使用统计、审计日志
- **多端**：浏览器（服务端托管）；Windows 桌面端（Tauri NSIS，内嵌后端，双击即用）；Linux 桌面端（Tauri deb/rpm/AppImage）；Android 端（已签名 APK，连接远程服务器）
- **单进程部署**：后端直接托管前端页面，一个端口、一个进程、零外部依赖

## 2. 技术栈

| 层       | 技术                                                     |
| -------- | -------------------------------------------------------- |
| 后端     | Python 3.11+ + FastAPI + Uvicorn                          |
| 前端     | Vue 3.5 + TypeScript 5.7 + Vite 6.1 + Ant Design Vue 4.2  |
| 状态管理 | Pinia 3.0                                                |
| 存储     | SQLite（知识库文档/向量/配置，WAL 模式）                  |
| LLM      | DeepSeek / Qwen（OpenAI 兼容接口）                       |
| 向量嵌入 | sentence-transformers（BAAI/bge-small-zh-v1.5，可选）    |
| 文档导出 | python-docx（Word）、html2pdf.js（PDF，浏览器端渲染）    |
| 部署     | **自包含发行包**（deb/rpm/NSIS/lite zip/APK，内嵌解释器+依赖，零容器形态） |

## 3. 仓库结构

单仓库（monorepo），文档与前后端同仓：

```text
├── README.md                         # 项目总览（本文件）
├── OPS.md                            # 运维唯一出处（部署/升级/验收/排障/数据/配置）
├── AGENTS.md                         # 工程约定（唯一出处）
├── backend-api.md / frontend-api.md  # API 契约文档
├── LICENSE                           # GPL-3.0
├── .env.example                      # 环境变量模板
├── _archive/                         # 历史归档（只读，勿据此操作）
├── backend/                          # Python 后端(app/、tests/、scripts/build_release.sh)
├── client/                           # Vue 前端 + src-tauri(Windows/Linux/Android 壳)
├── packaging/                        # 跨平台打包脚本与规范(见 packaging/README.md)
└── deploy/                           # 标准部署脚本(install.sh、systemd、windows/)
```

## 4. 快速启动

### 4.1 生产部署

**发行包从 [GitHub Release](https://github.com/T34851969/Proj/releases) 获取**，统一命名 `ai-resume-{client|server}-x86_64-{windows|linux}`（Android 为 `ai-resume-client-arm64-v8a-android`）：

| 资产 | 形态 | 说明 |
| --- | --- | --- |
| `ai-resume-client-x86_64-windows-setup.exe` | NSIS | Windows 桌面端，内嵌后端，双击即用 |
| `ai-resume-server-x86_64-windows-lite.zip` | zip | Windows 后端服务自包含包（计划任务部署） |
| `ai-resume-server-x86_64-linux.deb` / `.rpm` | deb/rpm | Linux 服务器自包含包，systemd 托管 |
| `ai-resume-client-x86_64-linux.deb` / `.rpm` / `.AppImage` | deb/rpm/AppImage | Linux 桌面端三件套 |
| `ai-resume-client-arm64-v8a-android.apk` | APK | Android 端（arm64-v8a，统一签名） |
| `SHA256SUMS.txt` | 清单 | 全部资产校验和 |

安装、升级、验收、排障的完整流程见 **[OPS.md](OPS.md)**。

### 4.2 本地开发

后端（自建虚拟环境，详见 [backend/README.md](backend/README.md)）：

```bash
cd backend
python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp ../.env.example .env      # 编辑填入 LLM 配置
./run.sh                     # 自激活 .venv，默认 127.0.0.1:8000
```

前端（Node 仅开发构建时需要，运行时不需要，详见 [client/README.md](client/README.md)）：

```bash
cd client
npm ci && npm run dev        # http://localhost:5173，代理 /api 到 8000
npm run build                # 产出 dist/，由后端托管
```

桌面壳调试：`cd client && npx tauri dev`（dev 会复用 8000 已有后端；无后端且已暂存 resources 时自动拉起）。

## 5. 环境变量

统一在 `.env` 中管理（完整清单见 `.env.example`），LLM 凭据由后端保管，前端不保存任何密钥：

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `LLM_API_URL` | LLM API 地址（OpenAI 兼容，含 `/chat/completions`） | — |
| `LLM_API_KEY` | API 密钥 | — |
| `LLM_MODEL` | 模型名称 | `qwen-plus` |
| `AUTH_MODE` | `required`=必须登录 / `optional`=允许匿名 | `required` |
| `REGISTRATION_MODE` / `INVITE_CODE` | `open`/`invite`/`closed` + 邀请码 | `open` / 空 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | 首次启动创建的运营者账号 | `admin` / 空 |
| `ACCESS_CODE` | 旧版共享口令（迁移兼容，将移除） | 空 |
| `RATE_LIMIT_PER_MINUTE` | 生成/对话接口每 IP 每分钟限流 | `30` |
| `PORT` / `HOST` | 服务端口/绑定地址 | `8000` / `127.0.0.1` |
| `CORS_ORIGINS` | 允许的跨域来源 | `localhost:5173` 等 |
| `CHAT_TEMPERATURE` | Chat 温度（0.0-2.0） | `0.7` |
| `DATA_DIR` | 数据目录 | `./data` |

模型调用 55 秒超时，失败自动降级本地规则生成（`meta.provider` 区分，`meta.fallbackReason` 给出原因）。

## 6. 关于 Node.js 的结论

- **运行时不需要 Node**：前端是构建后的纯静态文件（`client/dist`），由后端 FastAPI 直接托管，单端口 8000。
- **构建时仅在修改前端源码时需要 Node**（开发机上 `npm run build`）；发行包内已含构建产物，服务器与部署流程零 Node。
- **是否替换前端技术栈：否。** Vue 组件化、5 套简历模板与交互逻辑迁移等于全量重写，在发布窗口内风险极高且无收益；Node 只存在于开发机构建环节，不进入生产链路。

## 7. 测试

```bash
# 后端（backend/ 目录，虚拟环境内）
.venv/bin/python -m pytest   # 96 例：纯函数/SSE/中间件/知识库/静态托管/API 冒烟/档案/运营后台/鉴权

# 前端（client/ 目录）
npm run test                 # vitest：16 例，安全渲染/纯函数/口令存取
npm run build                # vue-tsc 严格类型检查 + 生产构建
```

## 8. CI/CD

单仓并行流水线（`.github/workflows/release-app.yml`），推送 `v*` tag 即自动发版：

- **tests**：pytest / vitest / vue-tsc 三道关卡，不通过不出包
- **prepare**：前端 dist 构建一次全流水线共享 + 预创建 Release（消灭多 job 并发挂资产的冲突）
- **四路并行构建**（互不牵扯，任一失败不影响其余平台的产物）：
  - `build-desktop-windows`：NSIS 安装包 + Windows lite zip
  - `client-linux`：Tauri deb / rpm / AppImage
  - `client-android`：APK（arm64-v8a，zipalign + apksigner 统一签名）
  - `packaging-linux`：服务器 deb / rpm（内含 **glibc 地板断言步**——运行时要求高于 glibc 2.17 直接判失败）

部署（`.github/workflows/deploy-windows.yml`）：staging 服务部署 + 健康检查，Release 事件附加 NSIS 安装包真机验收（静默安装 → 注册表验证 → 静默卸载）。注意：**CI 构建的 release 不会自动触发部署**（GitHub 对 GITHUB_TOKEN 创建的 release 抑制后续 workflow），发版后手动点火：`gh workflow run deploy-windows.yml --ref v<版本>`。

分支策略：`dev` 分支承载破坏性重构、激进测试与 staging 部署实验（deploy 支持 workflow_dispatch 指定 ref），main 只接收验证过的变更。

## 9. 工程规范

工程约定（运行时地板、零容器、资产命名、脚本编码、依赖上游策略、fork PR 隔离）见 **[AGENTS.md](AGENTS.md)**——该文件是唯一出处，本节不再重复。

## 10. 许可证

本项目以 **GNU General Public License v3.0** 发布，全文见 [LICENSE](LICENSE)。

项目派生自遵循 GPL 协议的上游项目，并在其基础上做了大幅重构与扩展；依据 GPL-3.0 的传染性条款，本项目的整体发行同样以 GPL-3.0 授权。二次分发或修改时请保留同样的许可与源码可得性。

学生团队、课程与学校信息记录于上文「项目背景」，属项目经历留痕，请勿删除。
