# AGENTS.md — 工程约定

> 本文件是工程约定的唯一出处，人和 AI 编码助手在改动本仓前都应先读。文档导航见 [README.md](README.md)。

## 文档导航
- 运维（部署/升级/验收/排障/数据/配置） → [OPS.md](OPS.md)（含 Windows staging 部署与验收）
- 打包规范与构建 → [packaging/README.md](packaging/README.md)
- API 契约 → [backend-api.md](backend-api.md) / [frontend-api.md](frontend-api.md)
- 历史归档（只读） → [_archive/](_archive/)

## 工程约定（提交前自查）
1. **零容器**：一切产物为原生包（deb/rpm/NSIS/zip/APK/AppImage）
2. **资产统一命名**：`ai-resume-{client|server}-x86_64-{windows|linux}` / `ai-resume-client-arm64-v8a-android`
3. **运行时地板**：服务器发行包内嵌解释器必须 standalone CPython（glibc 2.17 地板）；packaging-linux job 的断言步不得改弱
4. **systemd 包**：enable 不 start（不强制启动）；`.env` 为 conffile；安装位 `/opt/ai-resume`；包内零发行版依赖
5. **脚本编码**：bat 必须 CRLF+ASCII（.gitattributes 强制）；含中文的 ps1 必须 UTF-8 with BOM（PowerShell 5.1 无 BOM 按 GBK 读，解析必崩）
6. **Tauri**：`productName` 必须 ASCII（Linux 包名派生自它，中文会被 deb/rpm 拒绝）；窗口标题可中文
7. **APK**：统一签名（keystore 走 secrets），升级必须同签名
8. **依赖来源**：发版流水线（`release-app.yml`，产物面向所有用户）一律走官方上游 pypi.org / npmjs，不使用高校或第三方镜像——镜像不可作为长期可信锚点。自托管 staging 流水线不受此约束（`deploy-windows.yml` 按所在网络就近选源，不影响发版产物）
9. **fork PR 隔离**：fork PR 的代码永不接触自托管 runner（两条 workflow 均含 `if: github.event_name != 'pull_request'`，请勿移除）

## 发版与部署
- **发版**：改齐 `client/src-tauri/tauri.conf.json` 的 `version` 与 tag 一致 → 推 tag `v*` → CI 四路并行自动挂 9 资产到 Release
- **部署不自动**：CI 用 GITHUB_TOKEN 建的 release 不派发部署 workflow（GitHub 防递归）；发版后手动点火：
  ```bash
  gh workflow run deploy-windows.yml --ref v<版本>
  ```
- **分支**：main 只收验证过的变更；dev 承载破坏性实验（deploy 支持 `--ref dev` 直推 staging 验证）
- 全流程细节 → OPS.md §3 与 packaging/README.md
