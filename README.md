# AI 简历生成器

基于大模型的学生个人简历撰写智能体。用户填写个人信息、选择模板，系统通过 LLM（DeepSeek/Qwen）自动生成排版精美的简历，支持 PDF/Word 导出。

> **文档导航**:交接与运维事实 → [HANDOVER.md](HANDOVER.md) · 部署/升级/排障 → [DEPLOYMENT.md](DEPLOYMENT.md) ·
> API 契约 → [backend-api.md](backend-api.md) / [frontend-api.md](frontend-api.md) · Linux 部署细节 → [deploy/README-DEPLOY.md](deploy/README-DEPLOY.md) · 打包规范与构建 → [packaging/README.md](packaging/README.md)

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
├── README.md / REFACTOR_PLAN.md      # 文档
├── backend-api.md / frontend-api.md  # API 契约文档
├── TEAM_GUIDE.md                     # 团队协作指南
├── .env.example                      # 环境变量模板
├── backend/                          # Python 后端(app/、tests/、scripts/build_release.sh)
├── client/                           # Vue 前端 + src-tauri(Windows/Linux/Android 壳)
├── packaging/                        # 跨平台打包脚本与规范(见 packaging/README.md)
└── deploy/                           # 标准部署脚本(install.sh、systemd、windows/)
```

## 4. 快速启动

### 4.1 生产部署：自包含发行包（推荐，目标机零安装零网络）

**全部发行包从 [GitHub Release](https://github.com/T34851969/Proj/releases) 获取**：推送 `v*` tag 后 CI 自动构建并挂出，统一命名 `ai-resume-{client|server}-x86_64-{windows|linux}`（Android 为 `ai-resume-client-arm64-v8a-android`）：

| 资产 | 形态 | 说明 |
| --- | --- | --- |
| `ai-resume-client-x86_64-windows-setup.exe` | NSIS | Windows 桌面端，内嵌后端，双击即用 |
| `ai-resume-server-x86_64-windows-lite.zip` | zip | Windows 后端服务自包含包（计划任务部署） |
| `ai-resume-server-x86_64-linux.deb` / `.rpm` | deb/rpm | Linux 服务器自包含包，systemd 托管 |
| `ai-resume-client-x86_64-linux.deb` / `.rpm` / `.AppImage` | deb/rpm/AppImage | Linux 桌面端三件套 |
| `ai-resume-client-arm64-v8a-android.apk` | APK | Android 端（arm64-v8a，统一签名） |
| `SHA256SUMS.txt` | 清单 | 全部资产校验和 |

服务器包目标机行为：解包即用（内嵌 CPython 运行时+全部依赖，零外部安装、零外网访问），deb/rpm 安装后 systemd 单元 **enable 不 start**，启动执行 `systemctl enable --now ai-resume`；`.env` 为 conffile，升级不覆盖配置。实机验证矩阵：**Debian 12 / Fedora 44 通过**。

不打 tag 的本地出包（构建机已具备 backend/.venv 与 client/dist 时全程离线）：

```bash
./backend/scripts/build_release.sh [--full]                      # 自包含布局/tar 流程(lite 约 120MB,full 约 500MB)
bash packaging/linux/build-deb.sh --layout <布局目录> --version X.Y.Z --out dist-release   # 服务器 deb
bash packaging/linux/build-rpm.sh --layout <布局目录> --version X.Y.Z --out dist-release   # 服务器 rpm
```

Windows 包在 Windows 机器上执行 `backend\scripts\build_release.ps1` 产出，部署用 `deploy\windows\install.ps1`；
**桌面安装包**（Tauri，内嵌后端）用 `cd client && npx tauri build` 产出 NSIS exe。
细节见 [DEPLOYMENT.md](DEPLOYMENT.md)、[packaging/README.md](packaging/README.md) 与 [deploy/README-DEPLOY.md](deploy/README-DEPLOY.md)。

### 4.2 本地开发

后端（自建虚拟环境）：

```bash
cd backend
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp ../.env.example .env      # 编辑填入 LLM 配置
./run.sh                     # 或: python -m uvicorn app.main:app --reload --port 8000
```

前端（Node 仅开发构建时需要，运行时不需要）：

```bash
cd client
npm ci && npm run dev        # http://localhost:5173,代理 /api 到 8000
npm run build                # 产出 dist/,由后端(或任意静态服务器)托管
```

## 5. 后端 API

所有接口挂在 `/api` 前缀下，详细请求/响应见 [backend-api.md](backend-api.md)：

| 方法   | 路径                                   | 说明                              |
| ------ | -------------------------------------- | --------------------------------- |
| GET    | `/api/health`                          | 健康检查(无需口令)               |
| GET    | `/api/prompt-templates`                | 提示词模板列表                    |
| POST   | `/api/generate-resume`                 | 生成简历(返回 JSON)             |
| POST   | `/api/export-resume/docx`              | 导出 Word(请求体为 resumeData)  |
| GET    | `/api/knowledge-base/config`           | 知识库参数配置                    |
| PUT    | `/api/knowledge-base/config`           | 更新知识库参数                    |
| GET    | `/api/knowledge-base/documents`        | 知识库文档列表                    |
| POST   | `/api/knowledge-base/documents`        | 创建文本文档                      |
| POST   | `/api/knowledge-base/documents/upload` | 上传文件(.docx/.pdf/.txt/.md,≤20MB) |
| DELETE | `/api/knowledge-base/documents/{id}`   | 删除知识库文档                    |
| POST   | `/api/chat`                            | LLM 对话代理(SSE 流式)         |

> 除 `/api/health` 外，启用 `ACCESS_CODE` 后所有接口需携带 `X-Access-Code` 请求头。

## 6. 前端路由

| 路径        | 页面            |
| ----------- | --------------- |
| `/`         | 简历编辑与预览  |
| `/template` | 模板市场        |
| `/agent`    | AI 智能体工作台 |
| `/setting`  | 网站配置        |
| `/aiDeep`   | AI 深度交流     |

## 7. 环境变量

统一在 `.env` 中管理（见 `.env.example`），LLM 凭据由后端保管，前端不保存任何密钥：

| 变量               | 说明                                     | 默认值                  |
| ------------------ | ---------------------------------------- | ----------------------- |
| `LLM_API_URL`      | LLM API 地址(OpenAI 兼容)              | —                       |
| `LLM_API_KEY`      | API 密钥                                 | —                       |
| `LLM_MODEL`        | 模型名称                                 | `qwen-plus`             |
| `ACCESS_CODE`      | 访问口令(留空则不启用鉴权)             | 空                      |
| `RATE_LIMIT_PER_MINUTE` | 生成/对话接口每 IP 每分钟限流       | `30`                    |
| `PORT` / `HOST`    | 服务端口/绑定地址                        | `8000` / `127.0.0.1`    |
| `CORS_ORIGINS`     | 允许的跨域来源                           | `http://localhost:5173` |
| `CHAT_TEMPERATURE` | Chat 温度(0.0-2.0)                     | `0.7`                   |

模型调用 55 秒超时,失败自动降级本地规则生成(`meta.provider` 区分,`meta.fallbackReason` 给出原因)。

## 8. 关于 Node.js 的结论

- **运行时不需要 Node**：前端是构建后的纯静态文件(`client/dist`),由后端 FastAPI 直接托管,单端口 8000。
- **构建时仅在修改前端源码时需要 Node**(开发机上 `npm run build`);发行包内已含构建产物,服务器与部署流程零 Node。
- **是否替换前端技术栈：否。** Vue 组件化、5 套简历模板与交互逻辑迁移等于全量重写,在发布窗口内风险极高且无收益;
  Node 只存在于开发机构建环节,不进入生产链路。若未来团队完全停止前端迭代,才存在"去 Node"的可能。

## 9. 测试

```bash
# 后端(backend/ 目录,虚拟环境内)
pytest                       # 62+ 用例:纯函数/SSE/中间件/知识库/静态托管/API 冒烟

# 前端(client/ 目录)
npm run test                 # vitest:安全渲染/纯函数/口令存取
npm run build                # vue-tsc 严格类型检查 + 生产构建
```

## 10. 常用命令速查

```bash
# 发行包构建(构建机)
./backend/scripts/build_release.sh [--full]      # 自包含布局/tar 流程(lite/full)
bash packaging/linux/build-deb.sh --layout <布局> --version X.Y.Z --out dist-release   # 服务器 deb
bash packaging/linux/build-rpm.sh --layout <布局> --version X.Y.Z --out dist-release   # 服务器 rpm
ls dist-release/                                 # 产物 + SHA256SUMS

# 服务管理(目标机)
sudo systemctl {status|restart|stop} ai-resume   # systemd 管理
journalctl -u ai-resume -f                       # 日志
./deploy/start.sh                                # 前台启动(调试)
./deploy/status.sh                               # 状态+健康检查
./deploy/uninstall.sh                            # 卸载

# 后端开发(backend/,虚拟环境内)
./run.sh                                         # 启动开发服务器
pytest                                           # 单元测试
python test_api.py                               # API 冒烟(需服务已启动)

# 前端开发(client/)
npm run dev / build / test
```

## 11. CI/CD

单仓并行流水线（`.github/workflows/release-app.yml`），推送 `v*` tag 即自动发版：

- **tests**：pytest / vitest / vue-tsc 三道关卡，不通过不出包
- **prepare**：前端 dist 构建一次全流水线共享 + 预创建 Release（消灭多 job 并发挂资产的冲突）
- **四路并行构建**（互不牵扯，任一失败不影响其余平台的产物）：
  - `build-desktop-windows`：NSIS 安装包 + Windows lite zip
  - `client-linux`：Tauri deb / rpm / AppImage
  - `client-android`：APK（arm64-v8a，zipalign + apksigner 统一签名）
  - `packaging-linux`：服务器 deb / rpm（内含 **glibc 地板断言步**——运行时要求高于 glibc 2.17 直接判失败）

部署（`.github/workflows/deploy-windows.yml`）：staging 服务部署 + 健康检查，Release 事件附加 NSIS
安装包真机验收（静默安装 → 注册表验证 → 静默卸载）。注意：**CI 构建的 release 不会自动触发部署**
（GitHub 对 GITHUB_TOKEN 创建的 release 抑制后续 workflow），发版后手动点火部署流水线：
`gh workflow run deploy-windows.yml --ref v<版本>`。

**安全闸**：两条流水线均含 `if: github.event_name != 'pull_request'` 铁闸——fork PR 的代码永远不会
到达自托管 runner；仓库默认 workflow 权限已收紧为 `read`。

分支策略：`dev` 分支承载破坏性重构、激进测试与 staging 部署实验（deploy 支持 workflow_dispatch 指定
ref，可直接从 dev 验证破坏性变更），main 只接收验证过的变更。

## 12. 工程规范（红线）

1. **运行时红线**：服务器发行包内嵌的 Python 必须是 standalone CPython（glibc 2.17 地板），禁止
   发行版/nix 解释器进包——否则在旧 glibc 目标机直接拒载；CI 断言步强制拦截。
2. **零容器**：本项目拒绝一切容器形态，所有产物均为原生包（deb/rpm/NSIS/zip/APK/AppImage）。
3. **资产命名**：`ai-resume-{client|server}-{CPU架构}-{操作系统}`（如 `ai-resume-server-x86_64-linux.deb`），
   Android 为 `ai-resume-client-arm64-v8a-android.apk`；不得引入其他命名。
4. **Linux 打包**：systemd 单元 **enable 不 start**（安装不强制启动）；`.env` 为 conffile；安装位
   `/opt/ai-resume`；包内零发行版依赖。
5. **Windows 批处理**：必须 CRLF + ASCII（GBK 控制台对 LF/中文 bat 会碎裂解析），`.gitattributes` 已强制。
6. **Tauri**：`productName` 必须 ASCII（Linux 包名派生自它，中文会被 deb/rpm 拒绝）；窗口标题可中文。
7. **Android**：APK 统一签名（keystore 由仓库 secrets 托管），**升级必须同签名**。
8. **版本对齐**：发版前 `client/src-tauri/tauri.conf.json` 的 `version` 必须与 tag 一致。
