# AuraEye 前端账号与图片接口改造工作总结

> 文档用途：NestJS 后端接入交接  
> 更新时间：2026-08-06  
> 客户端：SwiftUI / iOS 17+  
> 后端框架：NestJS  
> API 前缀：`/v1`  
> 视觉结果 Schema：`1.0`

## 1. 本次工作结论

前端已经按照“账号上下文 + 图片资产 + 异步视觉任务 + 演示缓存”的方向完成改造。

已完成内容：

- 登录结果支持 `standard`、`demo` 两种账号模式。
- 登录后由 `SessionManager` 集中保存账号模式、feature flags 和 access token。
- 页面和 ViewModel 不再直接判断 `aurayetest` 用户名。
- 用户人像、眼影、眼线和工具图片均由用户主动从系统相册或相机选择。
- 演示账号选图后，在本地判断图片是否与演示缓存素材为同一张图。
- 匹配演示素材时读取端侧 SQLite/Bundle 缓存；不匹配时进入正式后端流程。
- 正式图片采用上传意图、对象存储直传、上传完成和异步任务轮询。
- `request_id`、`asset_id`、`job_id` 和未完成任务会写入端侧 SQLite。
- App 中断后可以恢复已有任务，不应重复创建付费 AI 任务。
- Metal shader 动态背景已恢复，该部分不需要后端接口。

本文件只描述当前改造实际使用的账号和视觉图片接口。Hermes 对话、虚拟试妆、妆容生成、全量账号同步不在本轮后端接入范围内。

## 2. 相比原方案的最终变化

以下内容以当前 Swift 代码为准：

1. 登录请求字段是 `account`，不是 `username`。
2. 当前 Swift 会把 `UIImage` 编码成质量 `0.9` 的 JPEG，文件名为 `portrait.jpg` 或 `item.jpg`，MIME 为 `image/jpeg`；当前不会直接上传 HEIC。
3. `POST /v1/media/assets/{asset_id}/complete` 当前请求体是空 JSON `{}`，`request_id` 通过 `X-Request-ID` 请求头传递。
4. `POST /v1/vision/item-recognition-jobs` 当前未发送 `client_observation`。
5. 演示账号不再自动把 Bundle 图片塞给页面。用户必须从系统相册/相机选择图片，客户端匹配成功后才调用对应缓存。
6. 图片缓存匹配不依赖用户选择的分类入口；以实际图片内容为准。

## 3. 总体调用架构

```text
SwiftUI View
  → ViewModel
  → AccountAware Provider
      ├─ standard
      │    → MediaAssetRepository
      │    → NestJS Media API
      │    → 对象存储
      │    → NestJS Vision Job API
      │    → JobPoller
      │
      └─ demo + use_demo_assets=true
           → 用户从系统相册/相机选图
           → DemoImageMatcher 本地视觉匹配
               ├─ 命中：SQLite / Bundle 演示结果
               └─ 未命中：与 standard 相同的正式后端流程
```

后端不能根据请求中的用户名判断演示模式。账号模式必须来自登录后的可信用户记录和 JWT 身份。

## 4. 全局 HTTP 约定

### 4.1 Base URL

Swift 从 App Info 中读取：

```text
API_BASE_URL=https://api.example.com
```

存在 `API_BASE_URL` 时，登录和视觉请求使用 NestJS 后端；未配置时才使用本地测试登录服务。

模拟器连接本机 NestJS 可使用 `http://127.0.0.1:<port>`。真机需要使用电脑局域网地址或 HTTPS 测试域名，并满足 iOS ATS 要求。

### 4.2 请求头

AuraEye API 请求：

```http
Accept: application/json
Content-Type: application/json
X-Request-ID: <request_id 或 UUID>
Authorization: Bearer <access_token>
```

登录接口可以不携带 Bearer Token。正式配置中不要把长期 `API_ACCESS_TOKEN` 写进 App。

对象存储直传只携带上传意图返回的 `upload_headers`，不能携带 AuraEye Bearer Token。

### 4.3 成功响应兼容规则

登录接口当前必须返回 envelope：

```json
{
  "request_id": "req_login_01",
  "data": {}
}
```

媒体和视觉任务接口同时兼容：

- 直接返回 DTO；
- `{ "request_id": "...", "data": DTO }`。

NestJS 建议全部统一为 envelope，避免不同模块返回风格不一致。

### 4.4 失败响应

当前 Swift 能解析以下两种错误格式：

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

推荐状态码：

| HTTP | 含义 |
|---:|---|
| 400 | DTO 或资源状态错误 |
| 401 | access token 无效 |
| 404 | 资源不存在或不属于当前用户 |
| 413 | 图片过大 |
| 422 | 图片或视觉结果无法处理 |
| 429 | 限流 |
| 500 | 内部错误 |
| 503 | 外部模型暂不可用 |

## 5. 账号接口

### 5.1 登录

```http
POST /v1/auth/login
Content-Type: application/json
```

当前 Swift 请求 DTO：

```json
{
  "account": "aurayetest",
  "password": "用户输入的密码"
}
```

推荐 NestJS 响应：

```json
{
  "request_id": "req_login_01",
  "data": {
    "access_token": "short-lived-access-token",
    "refresh_token": "refresh-token",
    "access_token_expires_at": "2026-08-06T12:00:00Z",
    "user": {
      "id": "user_demo_01",
      "username": "aurayetest",
      "display_name": "Mrs.Zhang",
      "account_mode": "demo"
    },
    "features": {
      "use_demo_assets": true,
      "allow_live_recognition_seed": true
    }
  }
}
```

字段表：

| 字段 | 类型 | 必需 | 说明 |
|---|---|---:|---|
| `access_token` | string | 是 | 后续 AuraEye API 的 Bearer Token |
| `refresh_token` | string | 否 | Swift 已解析，但本轮尚未实现自动刷新 |
| `access_token_expires_at` | ISO 8601 | 否 | 也兼容 `expires_at` |
| `user.id` | string | 是 | 稳定用户 ID |
| `user.username` | string | 是 | 登录名 |
| `user.display_name` | string | 否 | 缺失时前端回退到 username |
| `user.account_mode` | `standard` / `demo` | 强烈要求 | 账号能力路由依据 |
| `features.use_demo_assets` | boolean | 强烈要求 | 是否启用端侧演示素材 |
| `features.allow_live_recognition_seed` | boolean | 强烈要求 | 演示物品无缓存时是否允许创建一次远端任务 |

兼容期 Swift 仍可解析旧扁平结构：

```json
{
  "user_id": "user_01",
  "username": "user",
  "display_name": "User",
  "access_token": "token",
  "expires_at": "2026-08-06T12:00:00Z",
  "account_mode": "standard",
  "features": {
    "use_demo_assets": false,
    "allow_live_recognition_seed": false
  }
}
```

后端未返回 `account_mode` 时，前端目前仅在 DTO 解码层临时将成功登录的 `aurayetest` 映射为 `demo`。NestJS 上线明确字段后，应删除这段兼容判断。

### 5.2 当前会话边界

登录成功后 Swift 保存：

```text
userId
username
accountMode
features
accessToken
```

当前会话只保存在内存中，还没有完成 Keychain 持久化、refresh token 自动刷新和 App 重启自动登录。后端可以先实现登录和 JWT 校验，刷新/自动登录作为后续任务。

## 6. 用户选图与演示缓存

### 6.1 前端交互

- 用户点击上传后选择“拍照”或“相册”。
- 使用 iOS `UIImagePickerController`。
- `allowsEditing=false`，前端读取 `originalImage`。
- 演示账号同样必须完成这个选择过程，不会自动使用 Bundle 图片。

### 6.2 本地同图判断

相册可能改变 JPEG 压缩、色彩描述或元数据，因此客户端不比较原始文件字节。

当前匹配条件：

```text
9×8 灰度 dHash 汉明距离 <= 6
8×8 平均 RGB 距离 <= 0.10
宽高比相对差异 <= 0.025
```

图片方向会标准化；透明素材统一按白底合成。该视觉指纹只用于本地演示缓存路由，不上传 NestJS，也不能作为鉴权或身份识别依据。

### 6.3 演示素材映射

| demo_asset_key | 类型 | App 图片资源 | Bundle 结果 |
|---|---|---|---|
| `demo_portrait_01` | 人像 | `AvatarUserCutout` | `DemoVisualProfileSeed` |
| `demo_eyeshadow_palette_01` | 眼影 | `RecognizedEyeshadow` | `DemoEyeshadowSeed` |
| `demo_eyeliner_01` | 眼线 | `EyelinerProductIcon` | `DemoEyelinerSeed` |
| `demo_makeup_brush_01` | 工具 | `PracticeToolIcon` | `DemoMakeupBrushSeed` |

### 6.4 最终路由规则

| 账号/图片 | 人像分析 | 物品识别 |
|---|---|---|
| `standard` | 正式上传和异步任务 | 正式上传和异步任务 |
| `demo` 且匹配演示图 | 本地 `demo_seed`，不请求后端 | 读取缓存；需要时最多创建一次远端任务 |
| `demo` 但不匹配演示图 | 正式上传和异步任务 | 正式上传和异步任务 |
| `demo` 且 `use_demo_assets=false` | 正式流程 | 正式流程 |

物品识别入口的 `categoryHint` 不参与演示素材命中。图片识别为眼线时，即使用户从眼影入口上传，也会按眼线素材处理。

## 7. 图片资产接口

### 7.1 创建上传意图

```http
POST /v1/media/upload-intents
Authorization: Bearer <access_token>
Content-Type: application/json
```

请求：

```json
{
  "request_id": "req_upload_uuid",
  "file_name": "portrait.jpg",
  "content_type": "image/jpeg",
  "file_size": 2451021,
  "purpose": "vision"
}
```

物品图片的 `file_name` 为 `item.jpg`；演示首次识别可能为 `<demo_asset_key>.jpg`。

响应 DTO：

```json
{
  "asset_id": "asset_uuid",
  "upload_url": "https://object-storage.example/signed-url",
  "upload_method": "PUT",
  "upload_headers": {
    "Content-Type": "image/jpeg"
  },
  "expires_at": "2026-08-06T10:10:00Z"
}
```

| 字段 | 类型 | 必需 |
|---|---|---:|
| `asset_id` | string | 是 |
| `upload_url` | URL | 是 |
| `upload_method` | string | 是 |
| `upload_headers` | object<string,string> | 是，可为空对象 |
| `expires_at` | ISO 8601 | 否 |

### 7.2 对象存储直传

Swift 使用 `upload_method`、`upload_url` 和 `upload_headers` 发送 JPEG 二进制。对象存储返回任意 `2xx` 即视为成功。

### 7.3 确认上传完成

```http
POST /v1/media/assets/{asset_id}/complete
Authorization: Bearer <access_token>
X-Request-ID: req_upload_uuid
Content-Type: application/json
```

当前请求体：

```json
{}
```

响应：

```json
{
  "asset_id": "asset_uuid",
  "status": "ready"
}
```

NestJS 必须校验资源所有权、对象是否存在、文件大小、MIME 和文件魔数。供应商需要的 sRGB JPEG 派生图应由后端生成，不应由 iOS 接触供应商文件 ID。

## 8. 面部分析任务接口

### 8.1 创建任务

```http
POST /v1/vision/profile-jobs
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "request_id": "req_profile_uuid",
  "asset_id": "asset_uuid",
  "consent_version": "visual-analysis-v1"
}
```

建议返回 `202 Accepted`：

```json
{
  "contract_version": "0.1",
  "job_id": "job_uuid",
  "request_id": "req_profile_uuid",
  "job_type": "visual_profile",
  "asset_id": "asset_uuid",
  "status": "queued",
  "progress": {
    "stage": "queued",
    "poll_after_ms": 750
  }
}
```

## 9. 物品识别任务接口

### 9.1 创建任务

```http
POST /v1/vision/item-recognition-jobs
Authorization: Bearer <access_token>
Content-Type: application/json
```

当前 Swift 请求：

```json
{
  "request_id": "req_item_uuid",
  "asset_id": "asset_uuid",
  "recognition_scope": {
    "allowed_categories": [
      "eyeshadow_palette",
      "eyeliner",
      "makeup_brush"
    ],
    "max_items": 3
  }
}
```

后端标准类别只能返回：

```text
eyeshadow_palette
eyeliner
makeup_brush
```

## 10. 通用任务查询

```http
GET /v1/vision/jobs/{job_id}
Authorization: Bearer <access_token>
```

状态固定为：

```text
queued | running | succeeded | failed | timed_out | cancelled
```

创建任务响应中以下字段是 Swift 必需字段：

```text
job_id
request_id
job_type
asset_id
status
```

查询响应中 `job_id` 和 `status` 必需，其余任务元数据可选。运行中示例：

```json
{
  "contract_version": "0.1",
  "job_id": "job_uuid",
  "request_id": "req_item_uuid",
  "job_type": "item_recognition",
  "asset_id": "asset_uuid",
  "status": "running",
  "progress": {
    "stage": "recognizing",
    "poll_after_ms": 750
  },
  "result": null,
  "error": null
}
```

失败示例：

```json
{
  "job_id": "job_uuid",
  "status": "failed",
  "result": null,
  "error": {
    "code": "PROVIDER_UNAVAILABLE",
    "message": "vision provider unavailable"
  }
}
```

轮询规则：

- Swift 按 `poll_after_ms` 请求，实际限制在 250～5000 ms。
- 缺少 `poll_after_ms` 时默认 750 ms。
- Swift 单次主动等待上限为 90 秒。
- 所有终态立即停止轮询。
- 页面停止轮询不等于取消 NestJS 任务。
- 后端任务继续运行，之后应允许用同一 `job_id` 查询。

## 11. 面部分析成功结果 DTO

```json
{
  "profile_snapshot": {
    "face": {},
    "eyes": {},
    "brows": {},
    "skin": {},
    "provenance": []
  },
  "narrative": {
    "overall": "...",
    "eye_details": "...",
    "style_recommendation": "..."
  },
  "narrative_status": "succeeded",
  "warnings": [],
  "result_source": "remote_provider",
  "schema_version": "1.0"
}
```

必需字段：

- `profile_snapshot.face`
- `profile_snapshot.eyes`
- `profile_snapshot.brows`
- `profile_snapshot.skin`
- `profile_snapshot.provenance`
- `warnings`

`narrative`、`narrative_status`、`result_source`、`schema_version` 可选。结构化档案成功但文案失败时，仍应返回 `succeeded` 任务和有效 `profile_snapshot`。

## 12. 物品识别成功结果 DTO

```json
{
  "recognition_level": "L2",
  "items": [
    {
      "item_index": 0,
      "category": "eyeshadow_palette",
      "category_label_zh": "眼影盘",
      "category_confidence": 0.96,
      "bbox_0_999": [80, 100, 920, 900],
      "brand_text": "Brand",
      "product_name_text": "Palette",
      "shade_text": "暖棕",
      "visible_texts": ["Brand", "Palette"],
      "colors": [
        {"hex": "#C89A86", "proportion": 0.42}
      ],
      "needs_confirmation": true,
      "knowledge_keys": []
    }
  ],
  "warnings": [],
  "knowledge_keys": [],
  "result_source": "remote_provider",
  "schema_version": "1.0"
}
```

Swift 也兼容 `colors` 中直接出现十六进制字符串：

```json
"colors": ["#C89A86", "#8A5A4A"]
```

每个 item 的必需字段：

```text
item_index
category
category_label_zh
visible_texts
colors
needs_confirmation
knowledge_keys
```

识别完成后，前端仍会展示确认卡。用户确认后才写入当前本地化妆品表；本轮尚未把确认入柜接到 NestJS `POST /v1/cosmetics`。

## 13. request_id、幂等和任务恢复

前端规则：

- `request_id` 由 Swift 生成。
- 创建任务前先把 `request_id` 写入 SQLite。
- 上传完成后保存 `asset_id`。
- 收到任务响应后立即保存 `job_id`。
- 已有 `job_id` 时直接恢复查询，不重新创建任务。
- 同一重试复用原 `request_id`。

NestJS 必须保证：

```text
同一用户 + job_type + request_id = 同一个任务
```

如果后端包含 tenant，推荐数据库唯一键：

```text
tenant_id + user_id + job_type + request_id
```

创建任务 Controller 收到重复 `request_id` 时，应返回原有任务票据，不能再次调用 Qwen/玩美。

所有 asset 和 job 查询必须从 JWT 取用户身份并验证所有权。跨用户访问统一返回 404，不信任客户端提交的 `user_id` 或 `tenant_id`。

## 14. 演示账号缓存状态机

### 14.1 人像

```text
用户选图
  → 匹配 demo_portrait_01
      → 命中：读取 demo_seed，不上传、不创建 profile job
      → 未命中：正式上传和 profile job
```

### 14.2 眼影、眼线和工具

```text
用户选图并匹配 demo_asset_key
  → 查找有效 demo_results
      → 有：直接返回
      → 无：查找 demo_recognition_attempts
          → queued/running/uploaded：恢复原 job_id
          → failed/timed_out/cancelled：Bundle 降级，不自动重试
          → 无尝试记录：
              → allow_live_recognition_seed=false：Bundle 降级
              → allow_live_recognition_seed=true：创建一次正式任务
                  → 成功：保存 demo_qwen_cache
                  → 失败：保存失败状态并使用 demo_fallback
```

缓存有效性由以下值共同决定：

```text
demo_asset_key
asset_sha256
dataset_version
schema_version
model_version
```

结果来源值：

```text
remote_provider
demo_seed
demo_qwen_cache
demo_fallback
```

演示缓存目前是端侧 SQLite，不是 NestJS 的正式业务权威数据。NestJS 只需要保证演示账号在首次允许调用远端识别时，也能够正常使用上传和任务接口。

## 15. 当前端侧 SQLite 表

| 表 | 用途 |
|---|---|
| `vision_pending_jobs` | 正式账号和未命中演示图的任务恢复 |
| `demo_assets` | 演示素材 SHA、版本和复用的远端 asset ID |
| `demo_recognition_attempts` | 每个演示素材的一次识别尝试 |
| `demo_results` | 标准结果 DTO JSON 缓存 |

这些表不要求原样复制到后端。NestJS 的正式数据库至少应保存：

- media asset 及所有权；
- vision job；
- `request_id` 幂等键；
- provider task ID 和恢复状态；
- 标准化结果 JSON；
- 错误码、创建时间、完成时间。

## 16. NestJS 后端落地结构

应沿用现有 NestJS 项目，把当前核心能力包装到以下模块边界：

```text
src/
├─ modules/
│  ├─ auth/
│  │  ├─ auth.controller.ts
│  │  ├─ auth.service.ts
│  │  ├─ dto/login.dto.ts
│  │  └─ guards/jwt-auth.guard.ts
│  ├─ media/
│  │  ├─ media.controller.ts
│  │  ├─ media.service.ts
│  │  ├─ media.repository.ts
│  │  └─ dto/
│  └─ vision/
│     ├─ profile-jobs.controller.ts
│     ├─ item-recognition-jobs.controller.ts
│     ├─ vision-jobs.controller.ts
│     ├─ vision-jobs.service.ts
│     ├─ vision-jobs.repository.ts
│     ├─ dto/
│     └─ processors/
│        ├─ profile-job.processor.ts
│        └─ item-recognition-job.processor.ts
├─ providers/
│  ├─ object-storage/
│  ├─ qwen/
│  └─ perfect-corp/
└─ common/
   ├─ decorators/current-user.decorator.ts
   ├─ filters/http-exception.filter.ts
   ├─ interceptors/response-envelope.interceptor.ts
   └─ middleware/request-id.middleware.ts
```

职责：

- Controller：路由、JWT Guard、DTO 校验和 HTTP 状态码。
- Service：幂等、所有权、状态机和事务。
- Repository：数据库查询与唯一约束。
- Queue Processor：异步调用 Qwen/玩美并更新 job。
- Provider Adapter：把供应商结果转换成本文 DTO，不向 Swift 暴露供应商原始字段。
- Interceptor/Filter：统一 envelope 和错误结构。

DTO 建议使用 `class-validator` / `class-transformer`，全局 `ValidationPipe` 开启：

```ts
new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});
```

任务队列沿用 NestJS 的队列集成和现有基础设施；无论底层使用 BullMQ 还是其他队列，Controller 都必须立即返回 `job_id`，不能同步等待模型完成。

## 17. NestJS 实现顺序

### P0：登录与身份

1. `POST /v1/auth/login` 接收 `account/password`。
2. 用户表增加或确认 `account_mode`。
3. 登录响应返回 `features`。
4. JWT 中包含稳定 user ID；权限仍由数据库/服务端控制。

### P0：媒体资产

1. `POST /v1/media/upload-intents`。
2. 对象存储签名 URL。
3. `POST /v1/media/assets/:assetId/complete`。
4. 文件校验、所有权和 ready 状态。

### P0：视觉任务

1. 建立持久化 vision job 表和幂等唯一键。
2. 实现 profile 和 item 两个创建 Controller。
3. 接入 Queue Processor。
4. 实现 `GET /v1/vision/jobs/:jobId`。
5. 输出稳定 DTO，不直接返回供应商响应。

### P1：运维与契约

1. OpenAPI 3.1。
2. request ID 全链路日志。
3. 任务超时和失败恢复。
4. 双用户资源隔离测试。
5. Swift DTO 契约测试样例。

## 18. 后端联调验收

### 18.1 standard 账号

- 登录响应为 `standard` 且两个 feature 均为 false。
- 用户相册选图后可以创建 asset、完成上传并创建任务。
- profile 和 item HTTP 创建请求快速返回 `202`。
- App 按 `poll_after_ms` 获得结果。
- 同一 `request_id` 重复提交不会重复调用供应商。
- App 中断后使用原 `job_id` 能继续查询。

### 18.2 demo 账号

- 登录响应明确为 `demo`。
- 选择与演示人像相同的相册图片时，NestJS 不收到 profile 请求。
- 选择与三种演示物品相同的图片时，每个素材最多创建一次远端任务。
- 已缓存结果时不访问 NestJS。
- 选择其他图片时正常进入正式后端流程。
- 普通账号不能访问或命中演示账号的数据。

### 18.3 异常

- 无效 token 返回 401。
- 跨用户 asset/job 返回 404。
- 非法 MIME、魔数或超限图片被拒绝。
- 供应商失败后 job 进入固定终态。
- 日志不包含 Token、签名 URL、图片二进制和供应商密钥。

## 19. 当前前端验证结果

- Swift 全量 `swiftc -typecheck`：通过，0 错误。
- Xcode 工程文件和 entitlements 校验通过。
- 演示结果 JSON 校验通过。
- 登录、账号模式、媒体上传、任务 DTO、轮询和 SQLite 代码均已接入当前 ViewModel。
- 动态背景仍使用 Metal shader；该项没有新增后端依赖。
- 当前执行环境缺少可运行的 iOS Simulator Runtime/Metal Toolchain，最终 UI 和真实网络联调需在本机 Xcode 完成。

## 20. 前端代码索引

| 内容 | 文件 |
|---|---|
| 登录 DTO、账号模式 | `MakeupChat/Services/AuthenticationService.swift` |
| 登录 ViewModel | `MakeupChat/ViewModels/LoginViewModel.swift` |
| SessionContext | `MakeupChat/Services/SessionContext.swift` |
| HTTP Client | `MakeupChat/Services/RemoteAPIService.swift` |
| 上传、任务 DTO、JobPoller | `MakeupChat/Services/VisionInfrastructure.swift` |
| 面部分析 Provider | `MakeupChat/Services/VisualProfilePipeline.swift` |
| 物品识别 Provider | `MakeupChat/Services/ItemRecognitionPipeline.swift` |
| 图片匹配、演示缓存 | `MakeupChat/Repositories/DemoVisionRepository.swift` |
| SQLite Schema | `MakeupChat/Database/Schema.swift` |
| 相册/相机入口 | `MakeupChat/Components/CameraPickerView.swift` |

## 21. 本轮明确未完成的后端能力

为了防止联调时误判，以下内容不属于本次已完成闭环：

- refresh token 自动刷新；
- Keychain 会话持久化和自动登录；
- 用户确认后通过 `POST /v1/cosmetics` 云端入柜；
- 全量用户档案、化妆品柜、聊天和妆容历史同步；
- Hermes、虚拟试妆、妆容生成的新版异步接口。

NestJS 当前应优先完成第 17 节 P0 接口，完成后即可与现有 Swift 视觉流程联调。
