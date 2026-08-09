# AuraEye Swift API v1.1 前端改动汇总与后端兼容性说明

> 汇总日期：2026-08-09  
> 依据文档：`05_Swift_API_v1.1迁移与归一化操作文档.md`  
> 适用客户端：当前 `MakeupChat` SwiftUI 工程  
> 开发 API 基址：`https://api-dev.peterhigh.xyz/v1`

## 1. 结论

本次修改只涉及网络、认证选择、视觉任务和本地任务恢复，没有修改任何页面布局、素材、动画、shader 或用户交互。

对后端的总体影响：

- 现有 JSON 请求体和主要响应 DTO 没有删除字段，属于兼容迁移。
- 请求体中的旧 `request_id` 仍然发送。
- 新增 `Idempotency-Key` 请求头。
- 客户端不再生成或发送 `X-Request-Id`，改为读取服务端响应头。
- Base URL 已经包含 `/v1`，Endpoint 不再重复包含 `/v1`。
- 新增 `application/problem+json` 解码，同时保留旧错误信封兼容。
- 新增 `Location`、`Retry-After` 和服务端 request ID 的读取与 SQLite 保存。

如果当前 NestJS/Caddy 已按 v1.1 文档部署，修改可以直接兼容。如果后端仍完全按照旧行为运行，需要重点检查第 10 节。

## 2. 修改文件

| 文件 | 修改内容 |
|---|---|
| `MakeupChat.xcodeproj/project.pbxproj` | Debug 开发 API Base URL |
| `Services/RemoteAPIService.swift` | URL 拼接、Endpoint、请求头、响应头、Problem Details |
| `Services/AuthenticationService.swift` | Debug/Release 的未配置后端处理 |
| `Services/VisionInfrastructure.swift` | 媒体上传元数据、Job 状态、轮询和重试 |
| `Services/VisualProfilePipeline.swift` | 面部任务幂等键与恢复元数据 |
| `Services/ItemRecognitionPipeline.swift` | 物品任务幂等键与恢复元数据 |
| `Repositories/DemoVisionRepository.swift` | v1.1 任务字段读写 |
| `Database/Schema.swift` | SQLite 新字段定义 |
| `Database/DatabaseManager.swift` | 版本化 SQLite migration |

本轮没有修改 `Views/`、`Components/` 中的视觉与交互代码。

## 3. Base URL 与 Endpoint

### 修改前

接口调用字符串包含 `/v1`：

```text
/v1/auth/login
/v1/media/upload-intents
/v1/vision/profile-jobs
```

### 修改后

Debug Base URL：

```text
https://api-dev.peterhigh.xyz/v1
```

Endpoint 只保存版本后的相对路径：

```text
/auth/login
/media/upload-intents
/vision/profile-jobs
```

最终请求仍然是：

```text
https://api-dev.peterhigh.xyz/v1/auth/login
https://api-dev.peterhigh.xyz/v1/media/upload-intents
https://api-dev.peterhigh.xyz/v1/vision/profile-jobs
```

`APIEndpoint` 已集中保存路径，`APIClient` 会拒绝以 `/v1` 开头的 Endpoint，避免形成：

```text
/v1/v1/...
```

### 配置兼容

客户端优先读取：

```text
AURAEYE_API_BASE_URL
```

过渡期仍兼容旧键：

```text
API_BASE_URL
```

但旧 `API_BASE_URL` 的值现在也必须包含 `/v1`。如果仍配置为纯域名，最终请求会缺少版本前缀。

Debug 已配置开发地址。Release/TestFlight 当前没有写入正式地址；Release 缺少合法 HTTPS Base URL 时不会回退到本地测试账号，而是返回配置错误。

## 4. 请求标识修改

### 4.1 `Idempotency-Key`

以下创建操作现在发送：

```http
Idempotency-Key: idem_<uuid>
```

已覆盖：

- `POST /media/upload-intents`
- `POST /media/assets/{asset_id}/complete`
- `POST /vision/profile-jobs`
- `POST /vision/item-recognition-jobs`

同一个业务分析动作会先把 Key 写入 SQLite，断网、超时或 App 恢复时复用原 Key，不会自动生成新 Key。

当前同一分析动作的上传意图、上传完成和任务创建会复用同一个 Key。因此 NestJS 的幂等记录必须按以下范围隔离：

```text
user/tenant + HTTP method + route/operation + idempotency_key
```

如果后端只对 `user + idempotency_key` 建全局唯一约束，不区分接口，同一 Key 在三个不同接口上会被错误判断为请求体冲突。

### 4.2 旧 `request_id`

兼容阶段没有删除请求体中的旧字段：

```json
{
  "request_id": "req_profile_xxx"
}
```

后端可优先使用 Header 的 `Idempotency-Key`，Header 缺失时继续兼容旧 `request_id`。

### 4.3 `X-Request-Id`

修改前，Swift 会自行生成并发送：

```http
X-Request-ID: <客户端 UUID>
```

修改后，Swift 不再生成这个请求头。NestJS 应为每次 HTTP 请求生成独立追踪 ID，并在响应中返回：

```http
X-Request-Id: req_server_xxx
```

Swift 优先读取响应头；成功 JSON 中的旧 `request_id` 仍可作为兼容回退。

## 5. 响应头处理

`APIClient` 现在统一读取：

```text
X-Request-Id
Location
Retry-After
```

处理规则：

- `X-Request-Id`：用于错误定位并保存到任务记录。
- `Location`：创建 Job 后保存到 SQLite。
- `Retry-After`：支持整数秒和 HTTP 日期格式。
- 响应头缺失时不会导致成功 DTO 解码失败。

`Location` 和 `Retry-After` 当前都是兼容性可选字段。

## 6. HTTP 错误解码

新增标准 Problem Details：

```json
{
  "type": "https://api-dev.peterhigh.xyz/problems/idempotency-conflict",
  "title": "Idempotency conflict",
  "status": 409,
  "detail": "The same key was used with a different body",
  "instance": "/v1/vision/profile-jobs",
  "code": "IDEMPOTENCY_CONFLICT",
  "request_id": "req_server_xxx",
  "retryable": false,
  "errors": []
}
```

解码顺序：

1. `Content-Type: application/problem+json` 时解码 `APIProblem`。
2. 其他 Content-Type 尝试旧错误信封。
3. 两种格式都无法解码时返回 `invalidServerResponse`，只保留状态码和 request ID，不展示原始响应体。

旧错误格式仍兼容：

```json
{
  "code": "INVALID_IMAGE",
  "message": "图片无法处理"
}
```

或：

```json
{
  "error": {
    "code": "INVALID_IMAGE",
    "message": "图片无法处理"
  }
}
```

后端如果返回 Problem Details，必须正确设置：

```http
Content-Type: application/problem+json
```

否则客户端会按旧错误信封处理。

## 7. 图片上传流程

图片上传业务顺序没有改变：

```text
创建上传意图
→ 使用完整签名 URL 上传 OSS
→ 通知 NestJS 上传完成
→ 获得 asset_id
```

保持不变的部分：

- Swift 不写死 OSS Bucket 或 Endpoint。
- Swift 只使用后端返回的 `upload_url`、`upload_method` 和 `upload_headers`。
- OSS PUT 不附加 AuraEye Bearer Token。
- 当前上传数据仍是 `image/jpeg`。
- 上传完成请求体仍为 `{}`。

新增部分：

- 上传意图和上传完成携带 `Idempotency-Key`。
- 上传完成响应的 request ID、Location、Retry-After 会进入本地任务元数据。

## 8. 异步 Job 和轮询

### Job 状态

继续支持：

```text
queued
running
succeeded
failed
timed_out
cancelled
```

同时兼容后端返回美式拼写：

```text
canceled
```

客户端内部统一映射为 `cancelled`。

### 轮询规则

- `200 + job.status=failed` 仍按 Job 业务失败处理，不当作 HTTP 网络错误。
- `queued/running` 继续轮询。
- 响应头有 `Retry-After` 时优先使用。
- 否则使用 `progress.poll_after_ms`。
- 两者都没有时默认 750 ms。
- 单轮等待最长 90 秒。
- `409` 不生成新 Key，也不自动创建新 Job。
- `429/503` 只有 `retryable=true` 或存在 `Retry-After` 时才受控重试。
- 没有 `job_id` 时才用原 Idempotency Key 重试创建。

代码已经预留 401 后单次刷新授权的回调，但当前没有冻结的 refresh endpoint DTO，因此默认不会伪造刷新请求。现阶段遇到 401 仍会进入登录失效处理；待 OpenAPI 明确刷新接口后再接入真实 token 轮换。

## 9. SQLite migration

`vision_pending_jobs` 新增：

```text
idempotency_key   TEXT NULL
server_request_id TEXT NULL
location          TEXT NULL
retry_after       INTEGER NULL
```

`demo_recognition_attempts` 同样新增上述字段，保证演示账号首次远端识别也可以恢复。

迁移行为：

- 使用 `PRAGMA user_version = 2` 的显式 migration。
- 保留旧 `request_id` 列。
- 旧未完成任务执行：

```sql
idempotency_key = request_id
```

- 新任务先保存 `idempotency_key + preparing`。
- 收到 `asset_id`、`job_id`、服务端 request ID 后继续补写。
- 创建按账号、能力和幂等键隔离的唯一索引。
- 不删除旧 demo cache 和任务结果。

## 10. 对现有后端接口的影响

### 10.1 正常兼容的情况

以下条件满足时，现有后端接口不会被破坏：

- 公网真实路由仍为 `/v1/...`。
- Caddy 保留 `/v1`，NestJS 使用 `globalPrefix='v1'`；或者两者采用等价但不重复的配置。
- 后端允许额外的 `Idempotency-Key` 请求头。
- 请求体仍接受旧 `request_id`。
- 视觉接口仍返回现有 Job DTO。
- 旧错误信封至少包含 `code/message` 或嵌套 `error`。
- 对象存储上传意图字段没有变化。

### 10.2 可能不兼容的情况

| 后端现状 | 影响 | 处理建议 |
|---|---|---|
| Caddy 去掉 `/v1`，NestJS 同时没有 `v1` 前缀 | 新地址可能 404 | 统一 Caddy/NestJS 版本前缀职责 |
| 后端要求客户端必须发送 `X-Request-Id` | 请求可能被拒绝 | 改为 NestJS 生成并通过响应头返回 |
| Idempotency Key 仅按用户全局唯一，不区分接口 | 上传和 Job 创建可能产生 409 | 唯一键加入 method/route/operation |
| 后端对未知 Header 做严格拒绝 | 新请求可能 400 | 允许标准 `Idempotency-Key` |
| Problem JSON 未使用 `application/problem+json` | 可能走旧信封解码 | 修正 Content-Type 或保持旧信封结构 |
| `API_BASE_URL` 仍只配置域名、不含 `/v1` | 客户端请求缺少 `/v1` | 改为完整版本基址 |
| Release 未配置正式 HTTPS Base URL | Release 无法登录远端 | 发布前配置 Release/TestFlight 地址 |

### 10.3 不受影响的接口字段

以下当前请求体没有因本次修改而删除或改名：

- 登录 `account/password`。
- 上传意图 `request_id/file_name/content_type/file_size/purpose`。
- 面部任务 `request_id/asset_id/consent_version`。
- 物品任务 `request_id/asset_id/recognition_scope`。
- Job 查询路径参数 `job_id`。
- 面部和物品标准结果 DTO。

## 11. 尚未实施的 v1.1 项目

由于迁移文档明确要求不能猜测未冻结字段，下列内容尚未直接调用：

- Refresh Token 接口和真实 token 轮换。
- Media asset 删除接口。
- 用户确认后创建云端化妆品记录。
- 虚拟试妆任务的幂等迁移。

这些接口需要等待 OpenAPI v1.1 提供准确路径、请求 DTO 和响应 DTO。

## 12. 验证结果

- Swift 全量 `swiftc -typecheck`：通过，0 错误。
- `project.pbxproj`：`plutil` 校验通过。
- `git diff --check`：通过。
- Swift 源码中不存在继续拼接 `path: "/v1..."` 的调用。
- 旧 SQLite `request_id → idempotency_key` 迁移 SQL 已用临时数据库验证。
- 完整 Xcode build 仍被当前环境缺少 iOS Simulator Runtime 的 Asset Catalog 阶段阻断，不是 Swift API 代码错误。
- 开发域名在线健康检查因当前执行环境 DNS/网络权限未完成，仍需在本机或 CI 验证。

建议上线前执行：

```text
GET https://api-dev.peterhigh.xyz/v1/health/live       → 200
GET https://api-dev.peterhigh.xyz/health/live          → 404
GET https://api-dev.peterhigh.xyz/v1/v1/health/live    → 404
```

## 13. 后端联调检查清单

- [ ] NestJS/Caddy 最终只保留一层 `/v1`。
- [ ] NestJS 自动生成并返回 `X-Request-Id`。
- [ ] Idempotency 作用域包含 method/route。
- [ ] 相同 Key、相同接口、相同请求体返回原资源。
- [ ] 相同 Key、相同接口、不同请求体返回 `409 IDEMPOTENCY_CONFLICT`。
- [ ] 上传意图和上传完成接受 `Idempotency-Key`。
- [ ] Job 创建返回 `job_id`，并可选返回 `Location`。
- [ ] `429/503` 返回正确 `retryable` 或 `Retry-After`。
- [ ] Problem Details 使用 `application/problem+json`。
- [ ] 跨用户 asset/job 访问返回 404。
- [ ] Release/TestFlight 配置正式 HTTPS Base URL。

