# AuraAye 前后端分离 API 接口文档（Node.js 后端）

> 本文是全量业务接口规划。当前 NestJS 账号与图片视觉接入的实际契约，请以 `前端账号与图片接口改造工作总结_NestJS后端接入版.md` 为准。

> 版本：v1.0  
> 对应客户端：当前 `MakeupChat` SwiftUI 工程  
> API 前缀：`/v1`  
> 字段规范：HTTP JSON 使用 `snake_case`，时间使用 ISO 8601 UTC，例如 `2026-08-06T10:30:00Z`

## 1. 当前结论

当前 App 并不是“只差一个总接口”，而是同时包含三类数据：

1. 已预留远端实现：登录、AI 文字回复、化妆品识别、面部分析、妆容生成、妆容推荐。
2. 仍存放在本地 SQLite：用户档案、化妆品陈列柜、聊天历史、首次引导步骤、眼型库。
3. 仍是 Swift 静态数据或内存数据：妆容方案、妆容历史、任务、积分/等级、首次上妆状态。

如果目标是账号在不同设备登录后数据一致，后端至少需要实现本文标记为 **P0** 和 **P1** 的接口。只接现有 6 个 AI 接口，App 能调用模型，但不能实现完整的云端账号数据闭环。

### 1.1 接口优先级总览

| 优先级 | 模块 | 接口 |
|---|---|---|
| P0 | 认证 | 登录、刷新 Token、登出、当前用户 |
| P0 | 启动数据 | App bootstrap 聚合数据 |
| P0 | 用户档案 | 查询/修改档案、面部分析 |
| P0 | 化妆品 | 识别、确认入柜、列表、详情、修改、删除 |
| P0 | 聊天 | 会话列表/创建、消息列表、发送文字或图片 |
| P0 | 妆容 | 推荐、生成、方案详情 |
| P1 | 首次引导 | 查询/更新 onboarding 状态 |
| P1 | 妆容记录 | 完成一次上妆、历史列表、历史详情 |
| P1 | 任务成长 | 任务列表、领取奖励、积分/等级 |
| P2 | 基础资料 | 眼型/眼线样式库、资源签名上传 |

### 1.2 当前 Swift 已存在的 HTTP 调用

| HTTP | 当前实现 |
|---|---|
| `POST /v1/auth/login` | `RemoteAuthenticationService` |
| `POST /v1/chat/messages` | `RemoteAIAgentService`，属于兼容版单轮聊天 |
| `POST /v1/cosmetics/recognize` | `RemoteCosmeticsRecognitionService` |
| `POST /v1/profiles/analyze` | `RemoteFaceAnalysisService` |
| `POST /v1/makeup/generate` | `RemoteMakeupGenerationService`，尚未注入页面 |
| `POST /v1/makeup/recommendations` | `RemoteMakeupRecommendationService`，尚未注入页面 |

其余接口需要新增远端 Repository/Service，并替换当前本地 SQLite 或静态数组数据源。

## 2. 推荐技术架构

采用最常规的分层前后端分离结构：

```text
iOS SwiftUI
  └─ View / ViewModel
      └─ Service 或 Repository 协议
          ├─ Remote 实现 → HTTPS REST API
          └─ Local 实现  → SQLite 缓存/离线兜底

Node.js API
  └─ routes 路由
      └─ controllers 参数与响应
          └─ services 业务逻辑/模型调用
              └─ repositories 数据库访问
                  └─ PostgreSQL / MySQL
```

Node.js 建议使用 TypeScript + Express；如果现有服务是 JavaScript，可保持相同目录和接口，只去掉类型标注。推荐包：

- Web：`express`
- 参数校验：`zod`
- 数据库 ORM：`prisma`（也可以 Sequelize/TypeORM）
- 鉴权：`jose` 或 `jsonwebtoken`，密码哈希用 `argon2`/`bcrypt`
- 图片上传：`multer`
- 安全与日志：`helmet`、`pino-http`
- 限流：`express-rate-limit`，生产环境建议 Redis 限流
- API 文档：OpenAPI 3.1 + Swagger UI

推荐目录：

```text
backend/
├─ src/
│  ├─ app.ts
│  ├─ server.ts
│  ├─ config/
│  ├─ routes/v1/
│  ├─ controllers/
│  ├─ services/
│  ├─ repositories/
│  ├─ schemas/          # zod 请求校验
│  ├─ middleware/       # auth/error/request-id/rate-limit
│  ├─ clients/          # 大模型、对象存储、第三方服务
│  └─ types/
├─ prisma/schema.prisma
├─ openapi.yaml
├─ .env.example
└─ package.json
```

## 3. 全局协议

### 3.1 环境地址

```text
开发：http://127.0.0.1:3000
测试：https://api-test.example.com
生产：https://api.example.com
```

所有业务地址都拼接 `/v1`。不要把生产地址和密钥硬编码到 Swift 源码；客户端应通过 `.xcconfig` 写入 `API_BASE_URL`。

### 3.2 请求头

```http
Accept: application/json
Authorization: Bearer <access_token>
X-Request-ID: <UUID>
```

JSON 请求额外携带：

```http
Content-Type: application/json
```

建议所有创建型请求支持：

```http
Idempotency-Key: <UUID>
```

这样移动网络超时重试时不会重复入柜、重复记一次妆容或重复扣积分。

### 3.3 成功响应

当前 Swift `APIClient` 固定解包 `data`，因此所有成功响应必须统一为：

```json
{
  "request_id": "req_01J...",
  "data": {}
}
```

列表响应：

```json
{
  "request_id": "req_01J...",
  "data": {
    "items": [],
    "next_cursor": null,
    "has_more": false
  }
}
```

删除成功可返回 `200`：

```json
{
  "request_id": "req_01J...",
  "data": { "deleted": true }
}
```

### 3.4 失败响应

```json
{
  "request_id": "req_01J...",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "category 必须为 eyeshadow、eyeliner 或 brush",
    "details": [
      { "field": "category", "reason": "invalid_enum" }
    ]
  }
}
```

> 当前 Swift 只解码顶层 `code` 和 `message`。接入新格式时应同步升级 `APIErrorPayload`；在升级前，后端可临时同时返回顶层 `code`、`message` 保持兼容。

状态码约定：

| 状态码 | 用途 |
|---|---|
| 200/201 | 成功/创建成功 |
| 400 | JSON、查询参数或文件格式错误 |
| 401 | 未登录、Access Token 失效 |
| 403 | 已登录但无权限访问该资源 |
| 404 | 资源不存在 |
| 409 | 重复创建或版本冲突 |
| 413 | 图片过大 |
| 422 | 图片合法但模型无法识别/生成 |
| 429 | 请求频率过高 |
| 500 | 未预期的后端错误 |
| 503 | 模型或对象存储暂不可用 |

### 3.5 通用规则

- 客户端不要传 `user_id` 来决定数据归属；普通业务接口从 Token 的 `sub` 取得当前用户，避免越权。`user_id` 可出现在响应中。
- ID 建议使用 UUID v7、ULID 或数据库生成的不可预测 ID。
- 枚举使用稳定英文值；中文仅用于 `display_name`/`title`。
- 文件响应返回 HTTPS URL，不返回服务器本地绝对路径。
- 图片 URL 如果是短期签名 URL，同时返回 `expires_at`；客户端应下载到本地缓存。
- `null` 表示没有值，字段缺失表示后端版本尚不支持，二者不要混用。

## 4. 核心数据模型与字段

### 4.1 User 用户

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 用户唯一 ID |
| `account` | string | 是 | 登录账号，响应可不返回 |
| `display_name` | string | 是 | 昵称，对应当前 `Mrs.Zhang` |
| `status` | string | 是 | 当前状态/心情，如 `开心` |
| `credits` | integer | 是 | 积分，非负 |
| `level` | integer | 是 | 成长等级 |
| `level_progress` | number | 是 | `0...1` |
| `avatar_url` | string/null | 否 | 头像或虚拟分身 URL |
| `created_at` | datetime | 是 | 创建时间 |
| `updated_at` | datetime | 是 | 更新时间 |

### 4.2 BeautyProfile 面部/美妆档案

不要继续把 `user_file` 存成不可检索的任意 JSON 字符串。建议后端至少规范以下字段，同时保留 `attributes` 扩展对象：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `face_shape` | string/null | 否 | 如 `oval` |
| `skin_tone` | string/null | 否 | 如 `fair_pink` |
| `skin_undertone` | string/null | 否 | `cool/warm/neutral` |
| `eye_shape` | string/null | 否 | 如 `almond` |
| `recommended_style` | string/null | 否 | 推荐风格 |
| `preferences` | string[] | 是 | 用户偏好标签 |
| `source_photo_url` | string/null | 否 | 用户原始照片，敏感数据 |
| `portrait_url` | string/null | 否 | 透明人物或虚拟分身 PNG |
| `analysis_version` | string/null | 否 | 模型版本 |
| `attributes` | object | 是 | 后续扩展分析字段 |
| `updated_at` | datetime | 是 | 更新时间 |

### 4.3 Cosmetic 化妆品

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 实例 ID，不用 SKU 作为主键 |
| `sku` | string/null | 否 | 可识别到的商品 SKU |
| `display_name` | string | 是 | 展示名称 |
| `brand` | string/null | 否 | 品牌 |
| `category` | enum | 是 | `eyeshadow/eyeliner/brush` |
| `category_label` | string | 是 | `眼影/眼线/毛刷`，便于现有客户端过渡 |
| `tags` | string[] | 是 | 色系、用途等标签 |
| `color_hexes` | string[] | 是 | `#RRGGBB` |
| `material` | string/null | 否 | 材质 |
| `summary` | string/null | 否 | 简介 |
| `image_url` | string | 是 | 用户拍摄的商品图 |
| `recognition_confidence` | number/null | 否 | `0...1` |
| `recognition_source` | string | 是 | `ai/manual/import` |
| `created_at` | datetime | 是 | 入柜时间 |
| `updated_at` | datetime | 是 | 更新时间 |

### 4.4 Conversation / ChatMessage

Conversation：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 会话 ID |
| `title` | string | 是 | 会话标题 |
| `scene` | string/null | 否 | 如 `park/daily/formal` |
| `last_message_preview` | string/null | 否 | 列表摘要 |
| `created_at` | datetime | 是 | 创建时间 |
| `updated_at` | datetime | 是 | 最近消息时间 |

ChatMessage：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 消息 ID |
| `conversation_id` | string | 是 | 所属会话 |
| `sender` | enum | 是 | `user/assistant/system` |
| `kind` | enum | 是 | `text/photo/generating/makeup_plan` |
| `text` | string | 是 | 可为空字符串，但字段必须存在 |
| `attachments` | Attachment[] | 是 | 图片或生成结果 |
| `status` | enum | 是 | `sending/sent/failed` |
| `created_at` | datetime | 是 | 创建时间 |

Attachment：`id`、`type`（`image/makeup_plan`）、`url`、`thumbnail_url`、`width`、`height`、`makeup_plan_id`。

### 4.5 MakeupPlan 妆容方案

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | string | 是 | 方案 ID |
| `title` | string | 是 | 如 `清透甜美` |
| `tag` | string | 是 | 如 `少女感` |
| `summary` | string | 是 | 时长/场景说明 |
| `scene` | string | 是 | 场景稳定枚举或 slug |
| `image_url` | string/null | 否 | 效果图 |
| `color_hexes` | string[] | 是 | 推荐色板 |
| `estimated_minutes` | integer | 是 | 预计分钟数 |
| `steps` | MakeupStep[] | 是 | 有序步骤 |
| `model_version` | string/null | 否 | 生成模型版本 |
| `created_at` | datetime | 是 | 生成时间 |

MakeupStep 字段：`id`（string）、`step_number`（integer）、`title`、`tool`、`cosmetic_ids`（string[]）、`instruction`、`tip`、`preview_url`（string/null）。

### 4.6 OnboardingProgress

| 字段 | 类型 | 说明 |
|---|---|---|
| `current_step` | enum | `user_profile/cosmetics/makeup_generate/completed` |
| `completed_steps` | string[] | 已完成步骤 |
| `required_cosmetic_categories` | string[] | 固定三类或服务端配置 |
| `owned_cosmetic_categories` | string[] | 已入柜分类 |
| `is_completed` | boolean | 是否完成首次流程 |
| `updated_at` | datetime | 更新时间 |

### 4.7 MakeupHistory / Task

MakeupHistory：`id`、`makeup_plan_id`、`title`、`image_url`、`color_hexes`、`started_at`、`completed_at`、`duration_seconds`、`ordinal`。

Task：`id`、`type`、`title`、`reward_credits`、`status`（`pending/completed/claimed`）、`progress`、`target`、`completed_at`、`claimed_at`。

## 5. 认证接口（P0）

### 5.1 登录

```http
POST /v1/auth/login
```

请求：

```json
{
  "account": "aurayetest",
  "password": "用户输入密码",
  "device": {
    "device_id": "Keychain 中持久化的 UUID",
    "platform": "ios",
    "app_version": "1.0.0"
  }
}
```

响应 `data`：

```json
{
  "user": {
    "id": "usr_01J...",
    "display_name": "Mrs.Zhang",
    "status": "开心",
    "credits": 50,
    "level": 4,
    "level_progress": 0.4,
    "avatar_url": null,
    "created_at": "2026-08-06T10:00:00Z",
    "updated_at": "2026-08-06T10:00:00Z"
  },
  "access_token": "eyJ...",
  "access_token_expires_at": "2026-08-06T12:00:00Z",
  "refresh_token": "opaque-random-token",
  "refresh_token_expires_at": "2026-09-05T10:00:00Z"
}
```

> 当前 Swift 的 `AuthenticatedAccount` 期待顶层 `user_id`、`display_name`、`access_token`、`expires_at`。首轮最小改造可按旧结构返回；正式方案建议升级 Swift DTO 使用上述结构，并把 refresh token 存 Keychain。

### 5.2 刷新 Token

```http
POST /v1/auth/refresh
```

请求：`{"refresh_token":"..."}`。响应返回新的 access token；推荐 refresh token rotation，即每次同时换发新 refresh token并作废旧值。

### 5.3 登出

```http
POST /v1/auth/logout
```

请求：`{"refresh_token":"..."}`。服务端撤销该设备会话，响应 `{"logged_out":true}`。

### 5.4 当前用户

```http
GET /v1/me
```

响应为完整 User，客户端启动、Token 刷新后或个人页下拉刷新时调用。

## 6. 启动聚合接口（P0）

### 6.1 获取首页所需初始数据

```http
GET /v1/bootstrap
```

响应 `data`：

```json
{
  "user": {},
  "beauty_profile": null,
  "onboarding": {},
  "cabinet_summary": {
    "total": 3,
    "counts": { "eyeshadow": 1, "eyeliner": 1, "brush": 1 }
  },
  "recent_makeup_history": [],
  "active_tasks": [],
  "feature_flags": {
    "remote_chat_enabled": true,
    "makeup_generation_enabled": true
  },
  "server_time": "2026-08-06T10:30:00Z"
}
```

这个接口用于减少启动时的请求瀑布，不取代各模块的详情接口。天气继续由当前 Apple WeatherKit 获取，不需要放到业务后端。

## 7. 用户档案接口（P0）

### 7.1 查询档案

```http
GET /v1/me/profile
```

响应：`{"user": User, "beauty_profile": BeautyProfile|null}`。

### 7.2 修改基本资料与偏好

```http
PATCH /v1/me/profile
```

请求只传需要修改的字段：

```json
{
  "display_name": "Mrs.Zhang",
  "status": "开心",
  "preferences": ["清透自然", "暖色"]
}
```

服务端必须做字段白名单，客户端不能修改 `credits`、`level` 等系统字段。

### 7.3 上传照片并分析面部

```http
POST /v1/profiles/analyze
Content-Type: multipart/form-data
```

表单：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `image` | JPEG/PNG | 是 | 建议最大 10 MB，服务端二次压缩与去 EXIF |
| `generate_avatar` | boolean string | 否 | 默认 `true` |

响应 `data`：

```json
{
  "beauty_profile": {
    "face_shape": "oval",
    "skin_tone": "fair_pink",
    "skin_undertone": "cool",
    "eye_shape": "almond",
    "recommended_style": "清透自然",
    "preferences": [],
    "source_photo_url": "https://cdn.example.com/private/...jpg",
    "portrait_url": "https://cdn.example.com/private/...png",
    "analysis_version": "face-v2.1",
    "attributes": {},
    "updated_at": "2026-08-06T10:30:00Z"
  }
}
```

`portrait_url` 对应带 Alpha 的 PNG。生产环境推荐 URL，不推荐 `avatar_base64`；当前 Swift 若暂时不改，可额外兼容返回 `avatar_base64` 和字符串字典 `profile`。

### 7.4 单独重新生成虚拟分身（可选 P2）

```http
POST /v1/profiles/avatar
```

请求：`{"style":"default","source_photo_id":"media_..."}`。适合分身生成很慢或需要多个风格时拆分；否则合并在分析接口即可。

## 8. 化妆品陈列柜接口（P0）

### 8.1 识别化妆品（不入库）

```http
POST /v1/cosmetics/recognize
Content-Type: multipart/form-data
```

表单：`image` 必填；`category_hint` 可选，使用 `eyeshadow/eyeliner/brush`。响应：

```json
{
  "request_id": "req_...",
  "data": {
    "recognition_id": "rec_01J...",
    "expires_at": "2026-08-06T11:00:00Z",
    "suggestion": {
      "sku": null,
      "display_name": "九色眼影盘",
      "brand": null,
      "category": "eyeshadow",
      "category_label": "眼影",
      "tags": ["九色眼影", "日常大地色"],
      "color_hexes": ["#E8D6C3", "#CBA98E", "#A67C63"],
      "material": "细腻粉质",
      "summary": "九色组合，适合日常眼妆",
      "image_url": "https://cdn.example.com/private/temp/rec_...jpg",
      "recognition_confidence": 0.93
    }
  }
}
```

### 8.2 用户确认入柜

```http
POST /v1/cosmetics
Idempotency-Key: <UUID>
```

请求：

```json
{
  "recognition_id": "rec_01J...",
  "overrides": {
    "display_name": "我的通勤眼影盘"
  }
}
```

响应返回完整 Cosmetic，状态码 `201`。服务端应验证 `recognition_id` 属于当前用户且未过期。也可支持没有识别记录的手工创建，但必须由另一个明确的 schema 校验。

### 8.3 陈列柜列表

```http
GET /v1/cosmetics?category=eyeshadow&cursor=<cursor>&limit=20
```

响应 `items: Cosmetic[]`。不传 `category` 返回全部。`limit` 建议默认 20、最大 100。

### 8.4 化妆品详情

```http
GET /v1/cosmetics/:cosmetic_id
```

### 8.5 修改化妆品

```http
PATCH /v1/cosmetics/:cosmetic_id
```

允许修改：`display_name`、`category`、`tags`、`color_hexes`、`material`、`summary`。不能修改所属用户。

### 8.6 删除化妆品

```http
DELETE /v1/cosmetics/:cosmetic_id
```

建议软删除，并同步重新计算 onboarding 的已有分类集合。

## 9. AI 聊天接口（P0）

### 9.1 创建会话

```http
POST /v1/conversations
```

请求：`{"title":"今日妆容","scene":"park"}`。响应返回 Conversation，状态码 `201`。

### 9.2 会话列表

```http
GET /v1/conversations?cursor=<cursor>&limit=20
```

### 9.3 消息历史

```http
GET /v1/conversations/:conversation_id/messages?before=<message_id>&limit=30
```

消息列表建议按时间升序返回；翻页使用 `before` 获取更早记录。

### 9.4 发送消息

```http
POST /v1/conversations/:conversation_id/messages
Idempotency-Key: <client_message_id>
```

文字请求：

```json
{
  "client_message_id": "ios_7B2...",
  "kind": "text",
  "text": "我想要适合今天去公园的清透眼妆",
  "attachment_ids": []
}
```

图片应先用媒体上传接口得到 `attachment_id`，再随消息发送，避免大模型响应超时时图片也重复上传。响应：

```json
{
  "request_id": "req_...",
  "data": {
    "user_message": {},
    "assistant_message": {
      "id": "msg_...",
      "conversation_id": "conv_...",
      "sender": "assistant",
      "kind": "text",
      "text": "今天适合低饱和蜜桃色眼妆，我已经为你整理好步骤。",
      "attachments": [],
      "status": "sent",
      "created_at": "2026-08-06T10:31:00Z"
    },
    "suggested_actions": [
      { "type": "generate_makeup", "title": "生成妆容", "payload": { "scene": "park" } }
    ]
  }
}
```

模型上下文由后端按 `conversation_id`、用户档案和陈列柜查询，不要让客户端每次上传全部历史。

### 9.5 当前兼容接口

现有 Swift 可以暂时继续调用：

```http
POST /v1/chat/messages
```

请求 `{"user_id":"...","display_name":"...","message":"..."}`，响应 `{"message":"...","avatar_asset":"AvatarAI2"}`。建议内部转调新会话服务，并在客户端完成新接口迁移后弃用；不要同时维护两套业务逻辑。

### 9.6 流式回复（后续可选）

生成回复超过约 2 秒时可增加 SSE：`POST /v1/conversations/:id/messages/stream`，事件使用 `message.delta`、`message.completed`、`error`。首期也可以先用普通 JSON，降低联调复杂度。

## 10. 媒体接口（P1/P2）

### 10.1 小文件直接上传

```http
POST /v1/media
Content-Type: multipart/form-data
```

表单：`file`、`purpose`（`chat/profile/cosmetic`）。响应：

```json
{
  "id": "media_01J...",
  "type": "image",
  "url": "https://cdn.example.com/private/...",
  "thumbnail_url": "https://cdn.example.com/private/...",
  "width": 1170,
  "height": 2532,
  "mime_type": "image/jpeg",
  "size_bytes": 482193,
  "expires_at": null
}
```

流量上升后再改为“获取对象存储签名 URL → 客户端直传 → 完成确认”的三段式上传。

## 11. 妆容推荐与生成（P0）

### 11.1 生成上下文字段

后端应优先自己读取用户档案和陈列柜；客户端只传本次意图：

```json
{
  "scene": "daily",
  "weather": {
    "condition": "cloudy",
    "temperature_c": 26,
    "uv_index": 3,
    "district": "浦东新区"
  },
  "preferences": ["清透", "5分钟内"],
  "conversation_id": null
}
```

### 11.2 推荐列表

```http
POST /v1/makeup/recommendations
```

响应 `data.items: MakeupPlan[]`，首页建议返回 3 个。推荐结果可以没有完整步骤，但字段形状应保持一致，`steps` 可为 `[]`。

> 当前 Swift `RemoteMakeupRecommendationService` 期待 `data` 直接是数组。若采用 `{"items":[]}`，需要同步调整 Swift DTO；也可首期先返回数组以兼容现状。

### 11.3 生成完整方案

```http
POST /v1/makeup/generate
Idempotency-Key: <UUID>
```

可传上述上下文，以及可选的 `recommendation_id`。响应返回完整 MakeupPlan：

```json
{
  "request_id": "req_...",
  "data": {
    "id": "look_01J...",
    "title": "清透甜美",
    "tag": "少女感",
    "summary": "适合日常出行，5分钟画完",
    "scene": "daily",
    "image_url": "https://cdn.example.com/looks/look_...jpg",
    "color_hexes": ["#C87A72", "#CE8C80", "#DCADA0"],
    "estimated_minutes": 5,
    "steps": [
      {
        "id": "step_01J...",
        "step_number": 1,
        "title": "打底铺色",
        "tool": "大号铺色刷",
        "cosmetic_ids": ["cos_01J..."],
        "instruction": "保持眼部干燥，少量多次铺色。",
        "tip": "注意边缘自然，不要留下边界线。",
        "preview_url": "https://cdn.example.com/steps/step_1.jpg"
      }
    ],
    "model_version": "makeup-v3.2",
    "created_at": "2026-08-06T10:35:00Z"
  }
}
```

### 11.4 方案详情

```http
GET /v1/makeup/plans/:plan_id
```

用于 App 被系统重建、从历史记录进入或分享链接打开时恢复方案，不能只把生成结果放内存。

### 11.5 单步解释（可选 P1）

```http
POST /v1/makeup/plans/:plan_id/steps/:step_id/explanation
```

请求：`{"question":"为什么这里要少量多次？"}`。响应：`{"explanation":"..."}`。对应当前本地 `MakeupExplanationServicing`。

## 12. 首次引导接口（P1）

### 12.1 获取状态

```http
GET /v1/onboarding
```

返回 OnboardingProgress。客户端不应在每次 App 启动时清空云端 onboarding；当前 `DatabaseManager.resetForFreshLaunch()` 和 `resetStepsForNewLaunch()` 是演示规则，上线前必须移除或限制在 Demo 构建。

### 12.2 更新状态

```http
PATCH /v1/onboarding
```

请求示例：

```json
{
  "completed_step": "user_profile",
  "resource_id": "profile_01J..."
}
```

服务端根据真实资源验证：没有档案不能完成 `user_profile`，没有三类产品不能完成 `cosmetics`，没有方案不能完成 `makeup_generate`。不要信任客户端直接上传 `is_completed: true`。

## 13. 妆容历史接口（P1）

### 13.1 开始跟练（可选）

```http
POST /v1/makeup/sessions
```

请求：`{"makeup_plan_id":"look_..."}`，返回 `session_id` 和 `started_at`。

### 13.2 完成一次上妆

```http
POST /v1/makeup/sessions/:session_id/complete
Idempotency-Key: <UUID>
```

请求：`{"completed_step_ids":["step_1","step_2"],"completed_at":"..."}`。服务端写历史、完成相应任务、发放积分，并在同一数据库事务中完成。

如果首期不记录开始，可简化为：

```http
POST /v1/makeup/history
```

请求包含 `makeup_plan_id`、`duration_seconds`、`completed_at`。

### 13.3 历史列表与详情

```http
GET /v1/makeup/history?cursor=<cursor>&limit=20
GET /v1/makeup/history/:history_id
```

替换当前 `ProfileViewModel.defaultHistory` 和 `AppSession.makeupHistory`。

## 14. 任务、积分与等级（P1）

### 14.1 任务列表

```http
GET /v1/tasks?status=active
```

响应包含 Task[] 和最新 `credits`、`level`、`level_progress`。

### 14.2 领取奖励

```http
POST /v1/tasks/:task_id/claim
Idempotency-Key: <UUID>
```

响应：

```json
{
  "task": {},
  "credits": 70,
  "level": 4,
  "level_progress": 0.55
}
```

任务完成条件由服务端事件触发，例如 `profile.analyzed`、`cosmetic.created`、`makeup.completed`、`app.opened`；客户端不应自行声明任务已完成或直接增加积分。

## 15. 眼型与参考样式（P2）

```http
GET /v1/eye-styles?scene=daily&cursor=<cursor>&limit=20
GET /v1/eye-styles/:style_id
```

字段：`id`、`name`、`eye_svg_url`、`eyeliner_name`、`eyeliner_svg_url`、`main_color`、`secondary_color`、`scene`、`version`。替换当前本地 `eye_styles` 表。若该数据只供后端生成模型使用，不必暴露给 App。

## 16. 推荐数据库表

至少需要：

```text
users
auth_sessions
beauty_profiles
media_assets
cosmetics
cosmetic_recognitions
conversations
chat_messages
message_attachments
makeup_plans
makeup_steps
makeup_plan_cosmetics
makeup_sessions / makeup_history
onboarding_progress
task_definitions
user_tasks
credit_ledger
idempotency_keys
```

关键约束：

- 所有用户资源表包含 `user_id`，查询永远同时带当前用户条件。
- `credit_ledger` 记录每次积分变更，不只在 `users` 上改总数。
- `cosmetic_recognitions` 有 `expires_at` 和 `confirmed_at`。
- `makeup_steps` 对 `(plan_id, step_number)` 建唯一索引。
- 聊天消息对 `(conversation_id, created_at, id)` 建索引。
- 软删除表使用 `deleted_at`，默认查询排除已删除数据。

## 17. Node.js 实现骨架

### 17.1 Express 入口

```ts
import express from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { v1Router } from './routes/v1/index.js';
import { errorHandler } from './middleware/error-handler.js';

export const app = express();

app.use(helmet());
app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  const requestId = req.header('x-request-id') || randomUUID();
  res.locals.requestId = requestId;
  res.setHeader('x-request-id', requestId);
  next();
});
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/v1', v1Router);
app.use(errorHandler);
```

### 17.2 统一响应与错误

```ts
export function ok(res, data, status = 200) {
  return res.status(status).json({
    request_id: res.locals.requestId,
    data,
  });
}

export function errorHandler(err, _req, res, _next) {
  const status = err.status ?? 500;
  const code = err.code ?? 'INTERNAL_ERROR';
  const message = status === 500 ? '服务暂时不可用' : err.message;

  return res.status(status).json({
    request_id: res.locals.requestId,
    code,                         // 兼容当前 Swift
    message,                      // 兼容当前 Swift
    error: { code, message, details: err.details ?? [] },
  });
}
```

### 17.3 鉴权中间件

```ts
export async function requireAuth(req, _res, next) {
  try {
    const token = req.header('authorization')?.replace(/^Bearer\s+/i, '');
    if (!token) throw new ApiError(401, 'UNAUTHORIZED', '请先登录');
    const claims = await verifyAccessToken(token);
    req.auth = { userId: claims.sub, sessionId: claims.sid };
    next();
  } catch {
    next(new ApiError(401, 'INVALID_TOKEN', '登录状态已过期'));
  }
}
```

每个资源查询都应类似：

```ts
await prisma.cosmetic.findFirstOrThrow({
  where: { id: req.params.cosmeticId, userId: req.auth.userId, deletedAt: null },
});
```

不能先按 ID 查询，再在 Controller 中判断 user ID，否则容易遗漏越权分支。

### 17.4 图片识别路由

```ts
import multer from 'multer';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (_req, file, cb) =>
    cb(null, ['image/jpeg', 'image/png', 'image/heic'].includes(file.mimetype)),
});

router.post(
  '/cosmetics/recognize',
  requireAuth,
  recognitionRateLimit,
  upload.single('image'),
  cosmeticsController.recognize,
);
```

Controller 只校验和组装响应；图片存储、模型识别、结果持久化放在 Service。模型密钥只能放 Node.js 环境变量，绝不能下发到 iOS。

### 17.5 环境变量

```dotenv
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://...
JWT_PRIVATE_KEY=...
JWT_PUBLIC_KEY=...
ACCESS_TOKEN_TTL_SECONDS=7200
REFRESH_TOKEN_TTL_SECONDS=2592000
OBJECT_STORAGE_BUCKET=...
OBJECT_STORAGE_REGION=...
MODEL_API_KEY=...
```

提交 `.env.example`，把真实 `.env` 加入 `.gitignore`。

## 18. iOS 连接 Node.js 的具体方式

### 18.1 本机联调地址

- iOS 模拟器访问 Mac 上的 Node.js：通常使用 `http://127.0.0.1:3000`。
- 真机访问 Mac：使用 Mac 的局域网 IP，例如 `http://192.168.1.20:3000`，手机与 Mac 必须在同一网络，Node 监听 `0.0.0.0`。
- 正式环境：只使用 HTTPS 域名。

Node 启动时需要：

```ts
app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
```

Debug `.xcconfig`：

```text
API_BASE_URL = http://127.0.0.1:3000
```

Info.plist：

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

HTTP 只用于 Debug，需要配置最小范围 ATS 例外；不要在生产包中设置全局 `NSAllowsArbitraryLoads=true`。

### 18.2 客户端依赖注入

在 App 根部创建一次带 Token 的 `APIClient` 和 `AppServices`，页面只依赖协议。登录前使用匿名 Client 调登录；登录成功后把 Token 保存 Keychain，并创建已鉴权服务容器。

当前工程需要修改的关键位置：

| 页面/文件 | 当前数据 | 应替换为 |
|---|---|---|
| `ContentView.swift` | `LoginViewModel()` 和页面内部自行建 VM | 根部 `AppServices` 注入 |
| `HomeViewModel.swift` | 本地 User/EyeStyle | `/bootstrap`、`/makeup/recommendations` |
| `DisplayCabinetViewModel.swift` | 本地 `CosmeticsRepository` | 远端 cosmetics Repository + SQLite cache |
| `ChatViewModel.swift` | 本地消息表 + 单轮 Agent | conversation/messages API |
| `UserProfileSetupViewModel.swift` | 本地用户表 | profile analyze + profile fetch |
| `FirstTimeUseViewModel.swift` | 本地 onboarding 表 | onboarding API + makeup generate |
| `ProfileViewModel.swift` | 静态历史/任务 | history/tasks API |
| `MakeupPreviewView.swift` | `MakeupLookCatalog` | 远端 `MakeupPlan` |
| `MakeupStepsView.swift` | `MakeupLookCatalog` | 远端步骤 + 可选解释 API |

建议 Repository 统一提供：

```swift
protocol CosmeticsRepositoryProtocol {
    func list(category: String?) async throws -> [CosmeticDTO]
    func recognize(image: UIImage, categoryHint: String?) async throws -> RecognitionDTO
    func create(recognitionID: String, displayName: String?) async throws -> CosmeticDTO
    func update(id: String, patch: CosmeticPatchDTO) async throws -> CosmeticDTO
    func delete(id: String) async throws
}
```

Remote Repository 请求成功后更新 SQLite 缓存；无网络时只读缓存并明确展示“离线数据”。创建/删除是否支持离线队列应单独设计，首期不建议静默排队，避免冲突。

### 18.3 Token 处理

- Access token 和 refresh token 存 Keychain，不存 `UserDefaults`、Info.plist 或 SQLite 明文。
- 收到 401 后只允许单个 refresh 请求在飞行，其余请求等待结果，避免 refresh 风暴。
- refresh 成功后原请求最多自动重试一次；再次 401 则清理登录态回到登录页。
- 日志不得打印 Authorization、密码、人脸照片 URL 或完整档案。

### 18.4 Swift 当前协议兼容注意事项

当前 `RemoteAPIService.swift` 还需要补齐：

- `HTTPMethod` 增加 `patch`、`delete`。
- `APIClient` 支持 query items、空 body、文件字段名、Token 动态更新/刷新。
- 错误响应兼容新的 `error` 包裹。
- `AuthenticatedAccount` 增加 refresh token，持久化到 Keychain。
- 图片 API 优先解码 URL，不再把大 Base64 长期放在 JSON。
- 推荐接口的 `items` 包裹与 DTO 保持一致。
- 加入请求取消、有限重试和网络超时分类；不可重试 4xx。

## 19. 数据迁移策略

当前 App 每次启动会清空本地用户数据，这是演示行为。正式连接后端前：

1. 取消 Release 构建中的 `DatabaseManager.resetForFreshLaunch()`。
2. 登录后先调用 `/bootstrap`，用服务端数据覆盖或合并本地缓存。
3. 如果需要迁移已有本地数据，给每条记录增加 `remote_id`、`sync_status`、`updated_at`。
4. 迁移操作必须有幂等键，后端按用户和本地记录 ID 去重。
5. 服务端为最终事实源；本地 SQLite 是缓存，不再负责跨设备业务状态。

首期若没有真实用户数据，可以直接清空 Demo SQLite，避免把种子数据上传到用户账号。

## 20. 安全、隐私和运维要求

- 密码只保存 Argon2id/bcrypt 哈希，绝不保存明文。
- 人脸原图、透明肖像属于敏感数据：私有桶、最小权限签名 URL、静态加密、访问审计、可删除。
- 上传后检查 MIME 和真实文件头，去除 EXIF，限制像素和体积，必要时做恶意文件扫描。
- 登录、模型生成、图片识别分别限流。
- 数据库、模型和对象存储调用设置超时；外部失败返回稳定错误码。
- 所有请求记录 `request_id`，但日志脱敏。
- 提供 `GET /health`（进程存活）和 `GET /ready`（数据库等依赖就绪）。
- 数据库迁移随版本发布，先向后兼容地加字段，再升级客户端，最后移除旧字段。
- 人脸数据应提供查看、导出和删除能力；上线地区的隐私合规需单独审查。

## 21. 联调顺序与验收清单

推荐顺序：

1. `health`、统一响应、统一错误、request ID。
2. 登录、refresh、`GET /me`、Keychain。
3. `/bootstrap` 和用户档案。
4. 化妆品识别 → 用户确认 → 列表 → 修改/删除。
5. 会话创建 → 发消息 → 历史分页 → 图片消息。
6. 妆容推荐 → 生成 → 详情 → 页面恢复。
7. onboarding、妆容历史、任务和积分事务。
8. 弱网、401 刷新、429、超时、重复点击、真机图片上传。

上线前必须验证：

- 所有成功响应都有 `request_id` 和 `data`。
- 普通用户无法通过改 URL 访问其他用户资源。
- 重复请求不会重复入柜、重复历史、重复发奖励。
- 三类分类枚举在前后端映射一致。
- 色值为 `#RRGGBB`，日期为 ISO 8601 UTC。
- 图片 URL 可在有效期内访问，失效后可重新获取。
- App 冷启动、杀进程重开、换设备登录后数据正确恢复。
- Release 不再执行演示数据清空。
- Token、密码、模型密钥和人脸数据未出现在日志或 Git 中。

## 22. 首期最小可交付范围

如果需要最快完成可用联调，第一期可以只做以下 16 个接口：

```text
POST   /v1/auth/login
POST   /v1/auth/refresh
POST   /v1/auth/logout
GET    /v1/me
GET    /v1/bootstrap
GET    /v1/me/profile
PATCH  /v1/me/profile
POST   /v1/profiles/analyze
POST   /v1/cosmetics/recognize
POST   /v1/cosmetics
GET    /v1/cosmetics
DELETE /v1/cosmetics/:id
POST   /v1/conversations
GET    /v1/conversations/:id/messages
POST   /v1/conversations/:id/messages
POST   /v1/makeup/generate
```

首页推荐首期可以从 `/bootstrap` 返回，方案生成后直接持久化；历史、任务、眼型库在第二期补齐。这样已经能形成“登录 → 建档 → 产品入柜 → AI 对话 → 生成妆容”的完整主链路。
