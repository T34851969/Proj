# API 契约

> **低频查阅文档**：日常开发不用看。只在三种时候打开——改后端接口、接新客户端、排查 4xx/5xx。
>
> 本文是 HTTP 契约的**唯一出处**，内容与 `backend/app/routes/*.py`、`backend/app/models/schemas.py` 逐条对应。
> 部署、环境变量全量、数据目录见 [OPS.md](OPS.md)；工程约定见 [AGENTS.md](AGENTS.md)。
>
> 可运行的接口沙盒：服务启动后访问 `http://<host>:<port>/docs`（FastAPI Swagger UI）。

## 目录

- [0. 通用约定](#0-通用约定)
- [1. 接口总览](#1-接口总览)
- [2. 健康检查](#2-健康检查)
- [3. 账号与鉴权](#3-账号与鉴权)
- [4. 简历生成](#4-简历生成)
- [5. 导出 Word](#5-导出-word)
- [6. AI 对话（SSE）](#6-ai-对话sse)
- [7. 简历档案](#7-简历档案)
- [8. 知识库](#8-知识库)
- [9. 提示词模板](#9-提示词模板)
- [10. 模板市场分发](#10-模板市场分发)
- [11. 模型服务配置（admin）](#11-模型服务配置admin)
- [12. 运营后台（admin）](#12-运营后台admin)
- [13. 静态托管与 SPA 回退](#13-静态托管与-spa-回退)
- [附录 A 数据模型](#附录-a-数据模型)
- [附录 B 客户端接入要点](#附录-b-客户端接入要点)
- [附录 C 限额与超时](#附录-c-限额与超时)

---

## 0. 通用约定

| 项 | 约定 |
| --- | --- |
| 基础地址 | `http://<host>:<port>`，默认 `http://127.0.0.1:8000` |
| 接口前缀 | 除 `/` 与 SPA 回退外，**全部**为 `/api/*` |
| 编码 | 请求/响应均为 UTF-8 JSON；文件上传为 `multipart/form-data` |
| 时间 | ISO 8601 字符串，UTC 时区（如 `2026-11-18T00:26:30+00:00`） |
| 错误体 | `{"detail": "<可展示的中文文案>"}`；参数校验失败为 FastAPI 原生 422，`detail` 是数组 |

### 0.1 鉴权

请求头 `Authorization: Bearer <token>`，令牌由 `/api/auth/register` 或 `/api/auth/login` 签发。

| 路径 | 匿名可访问 | 说明 |
| --- | --- | --- |
| `GET /api/health` | 是 | 健康检查 |
| `/api/auth/*` | 是 | 注册/登录/登出/当前身份/改密 |
| 其余 `/api/*` | 视 `AUTH_MODE` | `required`（默认）→ 401；`optional` → 放行 |

- `AUTH_MODE=required` 且无有效令牌 → `401 {"detail":"未登录或令牌无效，请先注册/登录"}`
- `AUTH_MODE=required` 且非 admin 且对 `/api/knowledge-base/*` 做 `PUT`/`POST`/`DELETE` → `403 {"detail":"知识库管理仅限运营者账号"}`
- 令牌 7 天**滑动**过期（每次解析成功即续期），登出后立即失效，账号被禁用后令牌解析层直接拒绝。
- **迁移兼容**：`.env` 设置了 `ACCESS_CODE` 时，`X-Access-Code: <口令>` 头仍被接受，并映射为 `role=admin` 的内部用户（`id=0`、`username=__legacy_access_code__`）。新客户端不要依赖此通道。

### 0.2 限流

仅两处，滑动窗口 60 秒：

| 路由 | 键 | 超限 |
| --- | --- | --- |
| `POST /api/chat` | 已登录按 `user:<username>`，否则 `ip:<client.host>` | `429 {"detail":"请求过于频繁，请稍后再试"}` |
| `POST /api/generate-resume` | 同上 | 同上 |

窗口上限由 `RATE_LIMIT_PER_MINUTE`（默认 30）控制；设为 `0` 即关闭限流。

### 0.3 状态码语义

| 码 | 本项目中的含义 |
| --- | --- |
| 200 / 201 | 成功；201 仅用于 `auth/register`、`profiles`、`knowledge-base/documents`（含 upload） |
| 400 | 业务参数非法（文件名/格式/大小、旧密码错、URL 非法、档案超限等） |
| 401 | 未登录、令牌无效/过期、账号被禁用、用户名或密码错误、上游 API Key 无效 |
| 403 | 权限不足（非 admin 访问管理接口）、注册关闭、邀请码错误 |
| 404 | 资源不存在（档案、知识库文档、用户） |
| 409 | 用户名已被注册 |
| 422 | Pydantic 校验失败（字段长度/正则/枚举） |
| 429 | 限流或登录失败锁定 |
| 500 | 服务端内部错误（如 Word 生成失败） |
| 502 | 上游 LLM 未配置、连不上或返回错误 |
| 504 | 上游 LLM 超时 |

---

## 1. 接口总览

| 方法 | 路径 | 权限 | 说明 |
| --- | --- | --- | --- |
| GET | `/` | 匿名 | 前端入口页或运行提示 |
| GET | `/api/health` | 匿名 | 健康检查 |
| POST | `/api/auth/register` | 匿名 | 自助注册（201） |
| POST | `/api/auth/login` | 匿名 | 登录 |
| POST | `/api/auth/logout` | 登录 | 登出（吊销当前令牌） |
| GET | `/api/auth/me` | 登录 | 当前身份 |
| POST | `/api/auth/change-password` | 登录 | 修改自己的密码 |
| POST | `/api/generate-resume` | 登录 | 生成简历（限流） |
| POST | `/api/export-resume/docx` | 登录 | 导出 Word |
| POST | `/api/chat` | 登录 | AI 对话，SSE 流式（限流） |
| GET | `/api/profiles` | 登录 | 档案列表 |
| POST | `/api/profiles` | 登录 | 新建档案（201） |
| GET | `/api/profiles/{id}` | 登录 | 档案详情 |
| PUT | `/api/profiles/{id}` | 登录 | 更新档案 |
| DELETE | `/api/profiles/{id}` | 登录 | 删除档案 |
| GET | `/api/knowledge-base/config` | 登录 | 检索配置 |
| PUT | `/api/knowledge-base/config` | admin | 改检索配置 |
| GET | `/api/knowledge-base/documents` | 登录 | 文档列表 |
| POST | `/api/knowledge-base/documents` | admin | 新建文档（201） |
| POST | `/api/knowledge-base/documents/upload` | admin | 上传文件（201） |
| DELETE | `/api/knowledge-base/documents/{id}` | admin | 删除文档 |
| GET | `/api/prompt-templates` | 登录 | 提示词模板列表 |
| GET | `/api/templates` | 登录 | 模板市场元数据 |
| GET | `/api/llm-config` | admin | 模型服务配置 |
| PUT | `/api/llm-config` | admin | 保存模型服务配置（热生效） |
| DELETE | `/api/llm-config` | admin | 清除在线配置，回落 `.env` |
| POST | `/api/llm-config/test` | admin | 测试连通性 |
| GET | `/api/admin/users` | admin | 用户列表 |
| PATCH | `/api/admin/users/{id}/status` | admin | 启用/禁用用户 |
| POST | `/api/admin/users/{id}/reset-password` | admin | 重置用户密码 |
| GET | `/api/admin/stats` | admin | 统计概览 |
| GET | `/api/admin/events` | admin | 审计事件 |
| GET | `/{full_path}` | 匿名 | SPA 回退 |

---

## 2. 健康检查

### `GET /api/health`

无需鉴权。用于探活与排障，不查数据库。

**响应**

```json
{
  "ok": true,
  "now": "2026-11-18T00:26:30.123456+00:00",
  "provider": "llm-configured",
  "embedding": "ready",
  "auth": "disabled"
}
```

| 字段 | 取值 | 含义 |
| --- | --- | --- |
| `ok` | 恒 `true` | 进程存活即真 |
| `now` | ISO 8601 | 服务端当前时间 |
| `provider` | `llm-configured` / `local-fallback` | `.env` 里 `LLM_API_URL` 与 `LLM_API_KEY` 是否同时非空 |
| `embedding` | `ready` / `loading` / `unavailable: <原因>` / `not-installed` | 本地嵌入模型状态 |
| `auth` | `enabled` / `disabled` | **仅反映旧版 `ACCESS_CODE` 是否设置**，与 `AUTH_MODE` 无关 |

> `provider` 只看 `.env` 里的两个变量；运营者在界面保存的在线配置（`runtime.sqlite3`）**不会**让它变成 `llm-configured`。判断"实际能不能用 AI"请以 `POST /api/generate-resume` 返回的 `meta.provider`，或 `GET /api/llm-config` 的 `hasKey` 为准。

---

## 3. 账号与鉴权

### `POST /api/auth/register` → 201

**请求**

```json
{
  "username": "student01",
  "password": "abc12345",
  "email": "student01@example.com",
  "inviteCode": ""
}
```

| 字段 | 必填 | 约束 |
| --- | --- | --- |
| `username` | 是 | 4–32 位，正则 `^[A-Za-z0-9_-]+$` |
| `password` | 是 | 8–128 位，且**必须同时含字母与数字** |
| `email` | 否 | ≤254，可为空串 |
| `inviteCode` | 否 | ≤64，`REGISTRATION_MODE=invite` 时必填 |

**响应** `AuthResponse`（见附录 A），`role` 恒为 `user`。

**错误**

| 码 | detail | 触发 |
| --- | --- | --- |
| 403 | `当前未开放注册` | `REGISTRATION_MODE=closed` |
| 403 | `邀请码缺失或不正确` | `invite` 模式下码不对 |
| 409 | `用户名已被注册` | 重名 |
| 422 | `用户名须为 4-32 位字母、数字、下划线或连字符` / `密码长度至少 8 位` / `密码须同时包含字母和数字` | 校验失败 |

### `POST /api/auth/login`

**请求**：`{"username": "...", "password": "..."}`

**响应** `AuthResponse`。

**错误**

| 码 | detail | 触发 |
| --- | --- | --- |
| 401 | `用户名或密码不正确` | 用户不存在 / 密码错 / 账号被禁用（不区分，防枚举） |
| 429 | `失败次数过多，请 N 分钟后再试` | 同一 `(username, ip)` 连续失败 5 次，锁 15 分钟 |

### `POST /api/auth/logout`

吊销当前请求携带的令牌。**响应** `{"ok": true}`。无令牌时也返回成功（幂等）。

### `GET /api/auth/me`

**响应** `{"username": "...", "role": "user" | "admin", "email": "..."}`

未登录 → `401 {"detail":"未登录"}`。

### `POST /api/auth/change-password`

**请求** `{"oldPassword": "...", "newPassword": "..."}`

**响应** `{"ok": true}`。旧密码错 → `400 {"detail":"原密码不正确"}`；新密码同样须 8–128 位且含字母与数字。

---

## 4. 简历生成

### `POST /api/generate-resume`

**请求** `ResumeGenerateRequest`（24 个字段，全部可选，见附录 A）。

关键字段：

| 字段 | 默认 | 说明 |
| --- | --- | --- |
| `templateId` | `""` | 提示词模板 ID；**匹配不到时静默回落到第 1 个模板**，不报错 |
| `enableRag` | `true` | 关闭或检索词为空时不查知识库 |
| `retrievalTopK` | `null` | 1–100；`null` 用知识库配置里的默认值 |
| `wordCount` | `800` | 300–2000，目标字数 |
| `userLlm` | `null` | BYOK：本次请求临时使用的模型配置，服务端不落库 |

**RAG 检索词**由后端拼装：`targetRole`、`applicationPosition`、`major`、`courses`、`skillsText`、`selfIntroduction` 以空格连接，全部为空则不检索。

**响应** `GeneratedResumeResponse`

```json
{
  "resumeData": {
    "personalInfo": { "name": "...", "university": "...", "avatar": "", "...": "..." },
    "education": [{ "id": 1, "school": "...", "degree": "...", "major": "...", "startDate": "...", "endDate": "..." }],
    "workExperience": [],
    "skills": [{ "id": 1, "skillName": "..." }],
    "projects": [],
    "honors": [],
    "summary": "..."
  },
  "meta": {
    "provider": "llm",
    "templateId": "campus-concise",
    "templateName": "简约校招版",
    "knowledgeHits": [{ "documentId": "...", "documentName": "...", "category": "...", "score": 0.83 }],
    "fallbackReason": ""
  }
}
```

`meta.provider` 为 `llm` 表示大模型生成成功；`local-fallback` 表示降级为模板拼装，此时 `fallbackReason` 给出原因（如超时、JSON 解析失败、未配置）。**降级也是 200**，客户端应据 `meta.provider` 提示用户。

**错误**：`400 {"detail":"No prompt templates available"}` —— `data/prompt-templates.json` 缺失或为空。

---

## 5. 导出 Word

### `POST /api/export-resume/docx`

请求体就是上一步的 `resumeData`（`GeneratedResumeData`），不含 `meta`。

**响应**：二进制流

| 头 | 值 |
| --- | --- |
| `Content-Type` | `application/vnd.openxmlformats-officedocument.wordprocessingml.document` |
| `Content-Disposition` | `attachment; filename="resume.docx"` |

失败 → `500 {"detail":"生成 Word 文件失败: <异常>"}`。

---

## 6. AI 对话（SSE）

### `POST /api/chat`

**请求**

```json
{
  "messages": [
    { "role": "system", "content": "你是简历顾问" },
    { "role": "user", "content": "帮我改一下项目描述" }
  ],
  "stream": true,
  "userLlm": { "apiUrl": "https://api.deepseek.com/chat/completions", "apiKey": "sk-...", "model": "deepseek-chat" }
}
```

| 字段 | 约束 |
| --- | --- |
| `messages` | 至少 1 条；`role` ∈ `system` / `user` / `assistant` |
| `stream` | 默认 `true`；`false` 时服务端取上游完整响应后一次性推送 |
| `userLlm` | 可选 BYOK，三项都必填且非空才生效；缺省回落服务端配置 |

**响应**：`text/event-stream`

| 头 | 值 |
| --- | --- |
| `Content-Type` | `text/event-stream` |
| `Cache-Control` | `no-cache` |
| `Connection` | `keep-alive` |
| `X-Accel-Buffering` | `no`（禁用 nginx 缓冲） |

**SSE 协议（自定义简化版，不是 OpenAI 原格式）**

- 每个事件以空行 `\n\n` 结束，只有 `data:` 字段。
- 正文分片直接作为 `data:` 的内容，**不含 JSON 包装**。
- 正文里若含换行，会被编码为同一事件内的多行 `data:`，客户端必须用 `\n` 拼接还原（这是最容易写错的地方）。
- 终止符恒为 `data: [DONE]\n\n`。

```
data: 这段
data: 经历建议
data: 改成

data: 量化表述。
data: [DONE]

```

**错误**

| 码 | detail | 触发 |
| --- | --- | --- |
| 502 | `服务端未配置模型接口,可在「我的」中改用自带 Key 模式` | 无 `userLlm` 且 `.env` 未配 `LLM_API_URL`/`LLM_API_KEY` |
| 401 | `API Key 无效或已过期` | 上游返回 401 |
| 400 | `上游 API 返回 400: <body>` | 上游拒绝请求 |
| 502 | `上游 LLM API 请求失败: <异常>` / `上游 LLM API 错误 <code>: <body>` | 连接失败或上游 5xx |
| 504 | `连接上游 LLM API 超时（120秒）` | 建连/首包超时 |
| 502 | `无法连接到上游 LLM API: <url>` | 建连异常 |

> 上游连接在**开始推流之前**就完成校验，所以上表错误都是真实 HTTP 状态码，不会出现"200 + 断流"。但**流中途**的上游超时或网络错误无法再改状态码，此时服务端直接补 `data: [DONE]` 收尾，客户端看到的是一次正常结束——需要自行靠内容长度判断是否被截断。

---

## 7. 简历档案

档案是**账号级**的简历快照，用于多版本保存与切换。匿名请求一律 401（与 `AUTH_MODE` 无关）——匿名客户端的档案存在浏览器 localStorage 里。

### `GET /api/profiles`

**响应**：`ProfileMeta[]`（不含 `data`），按更新时间倒序。

### `POST /api/profiles` → 201

**请求** `{"name": "投字节的版本", "remark": "偏技术", "data": { ...ProfileSnapshot }}`

`name` 1–50 位必填，`remark` ≤200 可空，`data` 是任意 JSON 对象（服务端不校验内部结构，原样存取）。

**响应** `ProfileDetail`（`ProfileMeta` + `data`）。

### `GET /api/profiles/{id}` / `PUT /api/profiles/{id}` / `DELETE /api/profiles/{id}`

- `GET` → `ProfileDetail`；不存在 → `404 {"detail":"Profile not found"}`
- `PUT` 请求 `{"name"?: ..., "remark"?: ..., "data"?: ...}`，只更新给出的字段；返回更新后的 `ProfileDetail`
- `DELETE` → `{"removed": true}`；不存在 → 404

**错误**

| 码 | detail |
| --- | --- |
| 401 | `简历档案需要登录后使用` |
| 400 | `档案数量已达上限(50 份),请先删除不需要的档案`（仅 `POST`） |
| 400 | `档案数据过大(超过 512KB),请精简内容或压缩头像后重试`（`POST`/`PUT`） |
| 404 | `Profile not found`（`GET`/`PUT`/`DELETE`） |

---

## 8. 知识库

写操作（`PUT`/`POST`/`DELETE`）在 `AUTH_MODE=required` 下仅限 admin。存储为 `data/kb.sqlite3`（SQLite WAL），旧版 `knowledge-base.json` 在首次启动时自动迁移。

### `GET /api/knowledge-base/config`

**响应** `KnowledgeBaseConfig`，默认值：

```json
{ "chunkSize": 300, "chunkOverlap": 50, "retrievalTopK": 5, "matchAlgorithm": "token-overlap", "embeddingProvider": "local" }
```

### `PUT /api/knowledge-base/config`（admin）

**请求** `KnowledgeBaseConfigUpdate`，全部必填：

| 字段 | 范围 |
| --- | --- |
| `chunkSize` | 50–2000 |
| `chunkOverlap` | 0–500（且需小于 `chunkSize`） |
| `retrievalTopK` | 1–100 |
| `matchAlgorithm` | `token-overlap` / `vector-cosine` |
| `embeddingProvider` | `local` |

**响应** 更新后的 `KnowledgeBaseConfig`。

### `GET /api/knowledge-base/documents`

**响应** `KnowledgeDocument[]`：`{id, name, category, content, createdAt}`。

### `POST /api/knowledge-base/documents` → 201（admin）

**请求** `{"name": "...", "category": "...", "content": "..."}`

| 字段 | 约束 |
| --- | --- |
| `name` | 1–200 必填 |
| `category` | ≤100，默认 `""` |
| `content` | 1–500000 必填 |

### `POST /api/knowledge-base/documents/upload` → 201（admin）

`multipart/form-data`，字段名固定为 `file`。

| 限制 | 值 |
| --- | --- |
| 大小 | ≤ 20 MB |
| 格式 | `.docx` / `.pdf` / `.txt` / `.md`（按扩展名判断，并校验魔数） |

`name` 取文件名去扩展名，`category` 固定写入 `文件上传`。

**错误**

| 码 | detail |
| --- | --- |
| 400 | `缺少文件名` / `不支持的文件格式，仅支持 .docx / .pdf / .txt / .md` / `文件大小超过 20MB 限制` / `文件内容为空` |
| 400 | `文件内容与 .docx 格式不符(文件可能已损坏或被改名)`（`.docx` 需 `PK\x03\x04`，`.pdf` 需 `%PDF-`） |
| 400 | `未能从文件中提取到文本内容` |
| 500 | `文件解析失败: <异常>` |

### `DELETE /api/knowledge-base/documents/{id}`（admin）

**响应** `{"removed": true}`；不存在 → `404 {"detail":"Document not found"}`。

---

## 9. 提示词模板

### `GET /api/prompt-templates`

**响应** `PromptTemplate[]`，读自 `data/prompt-templates.json`。内置 5 套：

| `id` | `name` | 适用场景 |
| --- | --- | --- |
| `campus-concise` | 简约校招版 | 通用校招与实习投递 |
| `business-professional` | 商务正式版 | 管培生、运营、市场、职能岗位 |
| `creative-highlight` | 创意亮点版 | 新媒体、设计、产品、内容策划 |
| `tech-rag` | 技术研发版 | 前端、后端、算法、测试、数据 |
| `graduate-research` | 升学科研版 | 保研、考研复试、科研助理 |

`systemPrompt` 是喂给大模型的完整提示词，运营者可改。

---

## 10. 模板市场分发

### `GET /api/templates`

**响应**：`data/templates.json` 的原始内容（数组），**无 response_model**。文件不存在或 JSON 损坏时返回 `[]`，不报错。

元素形状：

```json
{
  "id": "202501",
  "name": "简洁模板-单栏",
  "description": "简约而不简单的单栏简历模板。",
  "folderPath": "templateA",
  "thumbnail": "preview.jpg",
  "author": "吃猫的鱼",
  "link": "https://github.com/weidong-repo"
}
```

`folderPath` 指向客户端内置的 Vue 组件目录，组件本身随客户端版本发布；服务端只负责分发"哪些模板可用"。当前 4 条（`templateA`–`templateD`）。

---

## 11. 模型服务配置（admin）

在线配置层优先于 `.env`，**保存即热生效**，无需重启。API Key 明文存本地 SQLite，接口永不回传明文。

### `GET /api/llm-config`

**响应** `LlmConfigResponse`

```json
{ "apiUrl": "https://api.deepseek.com/chat/completions", "model": "deepseek-chat", "hasKey": true, "keyMasked": "••••••••abcd", "source": "runtime" }
```

`source`：`runtime` = 来自在线配置，`env` = 回落 `.env`。`keyMasked` 规则：密钥长度 >8 时显示后 4 位，否则显示前 2 位。

### `PUT /api/llm-config`

**请求** `{"apiUrl": "https://...", "apiKey": "sk-...", "model": "deepseek-chat"}`

`apiUrl` 必填且须为 `http`/`https`（前端会先 `strip()`）；`model` 必填；`apiKey` 可留空（表示沿用已存的）。

**错误**：`400 {"detail":"API URL 须为 http(s) 地址"}` / `400 {"detail":"请填写模型名称"}`

### `DELETE /api/llm-config`

清除在线配置，回落 `.env`。**响应** 同 `GET`。

### `POST /api/llm-config/test`

**请求** `{"apiUrl"?: "...", "apiKey"?: "...", "model"?: "..."}` —— 三项都可省略，省略项依次取在线配置、`.env`。

**响应** `{"ok": true, "message": "连接成功（模型 deepseek-chat）", "latencyMs": 320}`

失败也是 200，`ok=false`，`message` 为原因：`API URL 或 API Key 未配置` / `连接超时（10 秒）` / `无法连接: <异常类名>` / `上游返回 <code>: <body 前 120 字>`。测试超时固定 10 秒。

**权限错误**：`401 {"detail":"请先登录运营者账号"}` / `403 {"detail":"模型服务配置仅限运营者账号"}`

---

## 12. 运营后台（admin）

### `GET /api/admin/users`

**响应** `AdminUser[]`：`{id, username, email, role, disabled, createdAt, activeTokens}`。

### `PATCH /api/admin/users/{id}/status`

**请求** `{"disabled": true}` → **响应** 更新后的 `AdminUser[]`（全量列表）。禁用即时生效（令牌解析层拒绝）。

**错误**：`400 {"detail":"不能禁用自己的账号"}` / `404 {"detail":"用户不存在"}`

### `POST /api/admin/users/{id}/reset-password`

**请求** `{"newPassword": "..."}`（8–128 位，含字母与数字）→ **响应** `{"ok": true}`；不存在 → 404。

### `GET /api/admin/stats`

**响应** `AdminStats`

```json
{
  "last30Days": { "generate": 120, "chat": 88, "login": 40, "userTotal": 12, "userDisabled": 1 },
  "generateProviders": { "llm": 100, "local-fallback": 20 },
  "generateDaily14d": [{ "day": "2026-11-17", "count": 9 }],
  "topUsers": [{ "username": "student01", "events": 31 }]
}
```

`last30Days` 的键是事件类型（见下），`userTotal` / `userDisabled` 由用户表实时补齐。

### `GET /api/admin/events`

| 查询参数 | 默认 | 约束 |
| --- | --- | --- |
| `limit` | 100 | 钳制到 1–500 |
| `offset` | 0 | ≥0 |
| `type` | `""` | 空 = 不过滤 |

**响应** `AdminEvent[]`：`{id, at, userId, username, type, detail}`，按 `id` 倒序。

**事件类型全集**

| `type` | `detail` 内容 | 触发点 |
| --- | --- | --- |
| `register` | — | 注册成功 |
| `login` | — | 登录成功 |
| `password_change` | `self` | 用户自助改密 |
| `generate` | `llm` / `local-fallback` | 生成简历 |
| `export_docx` | — | 导出 Word |
| `chat` | — | 对话 |
| `llm_config_update` | 模型名 | 保存在线模型配置 |
| `llm_config_reset` | — | 清除在线配置 |
| `user_disabled` / `user_enabled` | 目标用户名 | 后台启停用户 |
| `password_reset` | 目标用户名 | 后台重置密码 |

**权限错误**：`401 {"detail":"请先登录运营者账号"}` / `403 {"detail":"该操作仅限运营者账号"}`

---

## 13. 静态托管与 SPA 回退

服务端可选地托管前端构建产物，实现单端口部署（不需要 nginx / Node）。

**产物目录探测顺序**（取第一个含 `index.html` 的）：`STATIC_DIR` 环境变量 → `<包根>/static` → `<包根>/../client/dist`。

| 路由 | 行为 |
| --- | --- |
| `GET /` | 有静态目录 → 返回 `index.html`；否则 `{"message":"AI Resume Backend is running","docs":"/docs"}` |
| `GET /{full_path:path}` | 见下表 |

`/{full_path:path}` 的判定顺序：

1. 无静态目录 → `404 {"detail":"前端静态资源未部署(未找到 index.html)"}`
2. 路径以 `api/` 开头 → `404`（避免吞掉未匹配的 API 路径）
3. 含 `..` 或以 `/`、`\` 开头 → `404`（目录穿越防护）
4. 命中静态目录内的真实文件 → 返回该文件
5. 末段带扩展名（如 `.js`、`.png`）但文件不存在 → `404`（静态资源缺失不应回退成 HTML）
6. 其余 → 返回 `index.html`（history 路由刷新不 404）

两条路由都不出现在 `/docs` 的 schema 里。

---

## 附录 A 数据模型

以 TypeScript 书写，字段名与后端 Pydantic 模型完全一致（后端用驼峰，不转下划线）。约束写在注释里。

```ts
// ============ 通用 ============

interface AuthResponse {
  token: string;
  expiresAt: string;        // ISO 8601
  username: string;
  role: "user" | "admin";
}

interface AuthMeResponse { username: string; role: "user" | "admin"; email: string }

interface HealthResponse {
  ok: boolean;
  now: string;
  provider: "llm-configured" | "local-fallback";
  embedding: string;        // ready | loading | unavailable: <原因> | not-installed
  auth: string;             // enabled | disabled（仅反映 ACCESS_CODE）
}

// ============ 生成简历 ============

interface UserLlmConfig {
  apiUrl: string;           // <=512
  apiKey: string;           // 1..512
  model: string;            // 1..128
}

interface StudentEducationInput {
  school: string; degree: string; major: string; startDate: string; endDate: string;
}

interface StudentWorkInput {
  company: string; position: string; startDate: string; endDate: string; description: string;
}

interface StudentProjectInput {
  projectName: string; role: string; startDate: string; endDate: string;
  briefIntroduction: string; description: string;
}

interface ResumeGenerateRequest {
  // 基本信息（全为可选字符串，默认 ""）
  name: string; gender: string; age: string; phone: string; email: string;
  website: string; school: string; major: string; degree: string;
  politicalStatus: string;
  // 求职意向
  applicationPosition: string; targetRole: string; targetIndustry: string; ranking: string;
  // 长文本（带长度上限）
  courses: string;          // <=5000
  skillsText: string;       // <=5000
  honorsText: string;       // <=5000
  interests: string;        // <=2000
  selfIntroduction: string; // <=10000
  // 生成配置
  templateId: string;       // "" -> 回落第 1 个模板
  enableRag: boolean;       // 默认 true
  retrievalTopK?: number | null; // 1..100
  wordCount: number;        // 300..2000，默认 800
  // 结构化经历
  educationExperiences: StudentEducationInput[];
  workExperiences: StudentWorkInput[];
  projectExperiences: StudentProjectInput[];
  // BYOK
  userLlm?: UserLlmConfig | null;
}

// 输出侧模型：所有字符串字段接受显式 null（后端统一转空串），但 id 必须为整数
interface PersonalInfo {
  name: string; gender: string; phone: string; email: string; university: string;
  politicalStatus: string; website: string; avatar: string; major: string;
  applicationPosition: string; age: string;
}

interface EducationItem {
  id: number; school: string; degree: string; major: string; startDate: string; endDate: string;
}

interface WorkExperienceItem {
  id: number; company: string; position: string; startDate: string; endDate: string; description: string;
}

interface SkillItem { id: number; skillName: string }

interface ProjectItem {
  id: number; projectName: string; role: string; startDate: string; endDate: string;
  briefIntroduction: string; description: string;
}

interface HonorItem { id: number; honorName: string; date: string; description: string }

interface GeneratedResumeData {
  personalInfo: PersonalInfo;
  education: EducationItem[];
  workExperience: WorkExperienceItem[];
  skills: SkillItem[];
  projects: ProjectItem[];
  honors: HonorItem[];
  summary: string;
}

interface KnowledgeHit {
  documentId: string; documentName: string; category: string; score: number;
}

interface GeneratedResumeMeta {
  provider: "llm" | "local-fallback";
  templateId: string;
  templateName: string;
  knowledgeHits: KnowledgeHit[];
  fallbackReason: string;   // 仅降级时非空
}

interface GeneratedResumeResponse {
  resumeData: GeneratedResumeData;
  meta: GeneratedResumeMeta;
}

// ============ 对话 ============

interface ChatMessage { role: "system" | "user" | "assistant"; content: string }

interface ChatRequest {
  messages: ChatMessage[];  // 至少 1 条
  stream?: boolean;         // 默认 true
  userLlm?: UserLlmConfig;
}

// ============ 档案 ============

interface ProfileMeta {
  id: string; name: string; remark: string; createdAt: string; updatedAt: string;
}

interface ProfileDetail extends ProfileMeta { data: unknown }  // 服务端原样存取

// ============ 知识库 ============

interface KnowledgeBaseConfig {
  chunkSize: number; chunkOverlap: number; retrievalTopK: number;
  matchAlgorithm: string; embeddingProvider: string;
}

interface KnowledgeBaseConfigUpdate {
  chunkSize: number;        // 50..2000
  chunkOverlap: number;     // 0..500
  retrievalTopK: number;    // 1..100
  matchAlgorithm: "token-overlap" | "vector-cosine";
  embeddingProvider: "local";
}

interface KnowledgeDocument {
  id: string; name: string; category: string; content: string; createdAt: string;
}

// ============ 模板 ============

interface PromptTemplate {
  id: string; name: string; style: string; targetAudience: string;
  description: string; systemPrompt: string;
}

// ============ 模型服务配置 ============

interface LlmConfigResponse {
  apiUrl: string; model: string; hasKey: boolean;
  keyMasked: string; source: "env" | "runtime";
}

interface LlmTestResult { ok: boolean; message: string; latencyMs: number }

// ============ 运营后台 ============

interface AdminUser {
  id: number; username: string; email: string;
  role: "user" | "admin"; disabled: boolean;
  createdAt: string; activeTokens: number;
}

interface AdminStats {
  last30Days: Record<string, number>;
  generateProviders: Record<string, number>;
  generateDaily14d: Array<{ day: string; count: number }>;
  topUsers: Array<{ username: string; events: number }>;
}

interface AdminEvent {
  id: number; at: string; userId: number | null;
  username: string; type: string; detail: string;
}
```

---

## 附录 B 客户端接入要点

现有前端（`client/src`）的实现约定，新客户端照抄即可少踩坑。

### B.1 请求层

`client/src/api/agentAPI.ts`：

- `baseURL` 在请求拦截器里动态拼成 `${getServerBase()}/api` —— 服务端地址是运行时可配的（C/S 版可指向远端），不写死。
- 拦截器统一注入 `Authorization: Bearer <token>`，令牌取自 localStorage。
- 超时 **60 秒**。
- 响应拦截器把错误规范化为 `ApiError { code, message }`，`message` 优先用后端 `detail`，否则按状态码映射：401「未登录或登录已过期，请重新登录」/ 403「没有访问权限」/ 404「请求的资源不存在」/ 409「用户名已被注册」/ 413「上传文件过大(上限 20MB)」/ 422「输入格式不符合要求」/ 429「请求过于频繁，请稍后再试」/ 500「服务器内部错误，请稍后重试」/ 502「后端服务不可用或 LLM 未配置」/ 504「请求超时，请稍后重试」。
- 401 且有令牌时清会话并跳登录页（1 秒内不重复弹窗）。

### B.2 SSE 解析

`client/src/worker/aiWorker.ts`（跑在 Web Worker 里，因为工作线程读不到 localStorage，令牌由主线程随任务下发）：

- 用 `fetch` 而非 axios，超时 **125 秒**（后端上游 120 秒 + 5 秒余量），用 `AbortController` 实现。
- 按空行切事件，事件内多行 `data:` 用 `\n` 拼接——**不要**简单累加，否则回复里的换行全丢。
- 遇到 `data: [DONE]` 结束，不再追加内容。
- 网络/超时错误都以 `error` 标记回报主线程，绝不让 UI 悬挂。

### B.3 模板列表

`client/src/utils/getTemplates.ts`：先请求 `GET /api/templates`，为空或不可达时回退到随客户端打包的 `/templates.json`（离线桌面端可用）。

### B.4 前端路由与接口映射

| 路由 | 名称 | 主要接口 |
| --- | --- | --- |
| `/` | 简历制作 | `generate-resume`、`export-resume/docx`、`profiles*` |
| `/template` | 模板市场 | `templates` |
| `/agent` | 智能体工作台 | `chat`（SSE） |
| `/setting` | 网站配置 | `health`、本地服务端地址设置 |
| `/me` | 我的 | `auth/*`、`profiles*`、`llm-config*`（BYOK 本地存储） |
| `/admin` | 运营后台 | `admin/*`、`llm-config*`、`knowledge-base/*` |
| `/aiDeep` | AI 深度交流 | `chat`（SSE） |
| `/auth` | 注册/登录 | `auth/register`、`auth/login` |

---

## 附录 C 限额与超时

| 项 | 值 | 位置 |
| --- | --- | --- |
| 单文件上传 | 20 MB | `routes/knowledge_base.py` |
| 允许的上传格式 | `.docx` `.pdf` `.txt` `.md` | 同上 |
| 知识库单文档正文 | 500,000 字符 | `schemas.py` |
| 每用户档案数 | 50 | `services/profile_store.py` |
| 单份档案数据 | 512 KB | 同上 |
| 生成简历上游超时 | 55 秒 | `config.py` `llm_timeout` |
| 对话上游超时 | 120 秒（建连 10 秒） | `config.py` `chat_timeout` |
| 模型配置连通性测试 | 10 秒 | `routes/llm_config.py` |
| 限流窗口 | 60 秒 / 30 次 | `config.py` `rate_limit_per_minute` |
| 令牌有效期 | 7 天滑动 | `config.py` `token_ttl_days` |
| 登录失败锁定 | 5 次 / 15 分钟 | `config.py` `lockout_threshold` / `lockout_minutes` |
| 审计事件默认返回 | 100 条（上限 500） | `routes/admin.py` |

环境变量的完整清单与部署侧含义见 [OPS.md §6.2](OPS.md)。
