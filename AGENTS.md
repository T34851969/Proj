# AGENTS.md — Proj 仓库 Agent 约定

> 任何 AI Agent（Claude Code / Codex / ZCode / …）在本仓工作前必读。本文件只写 Agent 视角的入口与红线；文档导航见 README.md。

## 文档导航
- 部署/升级/排障 → [DEPLOYMENT.md](DEPLOYMENT.md)（含 §5 Windows staging 部署与验收）
- 打包规范与构建 → [packaging/README.md](packaging/README.md)
- API 契约 → backend-api.md / frontend-api.md；团队协作 → TEAM_GUIDE.md；Linux 部署细节 → deploy/README-DEPLOY.md

## 工程红线（违反即返工）
1. **零容器**：一切产物为原生包（deb/rpm/NSIS/zip/APK/AppImage）
2. **资产统一命名**：`ai-resume-{client|server}-x86_64-{windows|linux}` / `ai-resume-client-arm64-v8a-android`
3. **运行时地板**：服务器发行包内嵌解释器必须 standalone CPython（glibc 2.17 地板）；packaging-linux job 的断言步不得改弱
4. **systemd 包**：enable 不 start（不强制启动）；`.env` 为 conffile
5. **脚本编码**：bat 必须 CRLF+ASCII（.gitattributes 强制）；含中文的 ps1 必须 UTF-8 with BOM（PowerShell 5.1 无 BOM 按 GBK 读，解析必崩）
6. **Tauri**：`productName` 必须 ASCII（Linux 包名派生自它）；窗口标题可中文
7. **APK**：统一签名（keystore 走 secrets），升级必须同签名
8. **上游策略（用户裁定）**：高校/第三方镜像源为政治脆弱面，不可作信任锚点——CI 关键路径一律官方上游（pypi.org/npmjs）
9. **fork PR 铁闸**：fork PR 的代码永不接触自托管 runner（两条 workflow 均含 `if: github.event_name != 'pull_request'`，勿动）

## 发版与部署
- **发版**：改齐 `client/src-tauri/tauri.conf.json` 的 `version` → 推 tag `v*` → CI 四路并行自动挂 9 资产到 Release
- **部署不自动**：CI 用 GITHUB_TOKEN 建的 release 不派发部署 workflow（GitHub 防递归）；发版后手动点火：
  ```bash
  gh workflow run deploy-windows.yml --ref v<版本>
  ```
- **分支**：main 只收验证过的变更；dev 承载破坏性实验（deploy 支持 `--ref dev` 直推 staging 验证）
- 全流程细节 → DEPLOYMENT.md §5 与 packaging/README.md
