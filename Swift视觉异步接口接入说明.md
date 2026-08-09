# AuraEye Swift 视觉异步接口接入说明

> 本文为历史记录。后续 NestJS 后端实现和联调请以 `前端账号与图片接口改造工作总结_NestJS后端接入版.md` 为准。

> 实现日期：2026-08-06  
> 契约版本：0.1  
> Schema 版本：1.0

## 1. 已完成范围

本轮只修改视觉接口和 `aurayetest` 演示数据路由：

- 登录响应兼容嵌套 `user`、`account_mode`、`features`、refresh token。
- `SessionManager` 集中保存 `SessionContext`，页面和 ViewModel 不判断用户名。
- 普通账号改用媒体上传意图、对象存储直传、上传完成、创建异步任务、轮询任务。
- 面部分析和物品识别分别提供正式/演示 Provider，并由账号上下文动态路由。
- `request_id` 在任务创建前持久化，`job_id` 收到后立即持久化。
- 任务查询支持 `queued/running/succeeded/failed/timed_out/cancelled`。
- 演示面部档案使用 Bundle 数据并写入/读取 SQLite。
- 三个演示物品按素材 SHA、schema 和模型版本执行最多一次远端识别。
- 识别失败后使用 Bundle 标准 DTO 降级，不自动再次调用。
- 识别结果仍经过原有确认卡，用户确认后才写入 `cosmetics`。

未修改 Hermes 对话、上妆步骤、虚拟试妆和全量同步。

## 2. 主要文件

| 内容 | 文件 |
|---|---|
| 登录 DTO、AccountMode、feature flags | `Services/AuthenticationService.swift` |
| SessionContext 集中路由 | `Services/SessionContext.swift` |
| APIClient flexible decode、对象存储上传 | `Services/RemoteAPIService.swift` |
| Media DTO、Job DTO、JobPoller、统一错误 | `Services/VisionInfrastructure.swift` |
| 面部分析正式/演示 Provider | `Services/VisualProfilePipeline.swift` |
| 物品识别正式/演示 Provider | `Services/ItemRecognitionPipeline.swift` |
| Job、演示素材、尝试、结果持久化 | `Repositories/DemoVisionRepository.swift` |
| SQLite migration | `Database/Schema.swift` |
| 页面状态接入 | `ViewModels/UserProfileSetupViewModel.swift`、`DisplayCabinetViewModel.swift` |
| 首次引导接入 | `Services/OnboardingService.swift` |

## 3. 登录响应 DTO

前端优先解析：

```json
{
  "request_id": "req_login_01",
  "data": {
    "access_token": "token",
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

兼容旧扁平字段：`user_id`、`username`、`display_name`、`access_token`、`expires_at`。
后端未返回 `account_mode` 时，只在 `AuthenticatedAccount` 解码层临时把成功响应中的
`username=aurayetest` 映射为 demo；页面没有用户名判断。

## 4. MediaAssetRepository

调用顺序：

```text
POST /v1/media/upload-intents
PUT/POST <upload_url>
POST /v1/media/assets/{asset_id}/complete
```

创建意图请求：

```json
{
  "request_id": "req_upload_uuid",
  "file_name": "portrait.jpg",
  "content_type": "image/jpeg",
  "file_size": 2451021,
  "purpose": "vision"
}
```

前端接受上传意图直接 JSON 或 `{request_id,data}` 包裹：

```json
{
  "asset_id": "asset_uuid",
  "upload_url": "https://object-storage/...",
  "upload_method": "PUT",
  "upload_headers": {"Content-Type":"image/jpeg"},
  "expires_at": "2026-08-06T10:10:00Z"
}
```

对象存储请求只发送 `upload_headers`，不会发送 AuraEye Bearer Token。
当前相机/相册层提供 `UIImage`，因此上传前编码为真实 `image/jpeg`；没有伪报 HEIC。

## 5. 通用任务 DTO 与轮询

创建任务响应由 `AIJobTicketDTO` 解码，必须包含：

```text
job_id, request_id, job_type, asset_id, status
progress.stage, progress.poll_after_ms
```

查询：

```http
GET /v1/vision/jobs/{job_id}
```

成功时 `AIJobDTO<Result>.result` 解码为能力对应 DTO。轮询规则：

- 按 `poll_after_ms`，并限制在 250～5000 ms。
- 六个固定状态之外会解码失败，不会无限轮询。
- 所有终态停止轮询。
- 页面 Task 取消会停止本地轮询，不调用后端取消接口。
- 客户端主动等待上限为 90 秒；保留 SQLite 中的 `job_id`。
- 同一重试复用已保存 `request_id`；已有 `job_id` 时只查询原任务。

## 6. 面部分析

创建：

```http
POST /v1/vision/profile-jobs
```

```json
{
  "request_id": "req_profile_uuid",
  "asset_id": "asset_uuid",
  "consent_version": "visual-analysis-v1"
}
```

成功结果字段：

```text
profile_snapshot.face
profile_snapshot.eyes
profile_snapshot.brows
profile_snapshot.skin
profile_snapshot.provenance
narrative.overall
narrative.eye_details
narrative.style_recommendation
narrative_status
warnings
result_source（可选，前端会补 remote_provider）
schema_version（可选，前端会补 1.0）
```

`profile_snapshot` 内部字段使用可 Codable 的 `JSONValue` 保留后端扩展字段。
`narrative_status` 失败不影响结构化档案解码。

演示账号不创建上传或 profile job，读取：

```text
UIImage asset: AvatarUserCutout
NSDataAsset: DemoVisualProfileSeed
SQLite source: demo_seed
```

## 7. 物品识别

创建：

```http
POST /v1/vision/item-recognition-jobs
```

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

结果 DTO：

```text
recognition_level
items[].item_index
items[].category
items[].category_label_zh
items[].category_confidence
items[].bbox_0_999
items[].brand_text
items[].product_name_text
items[].shade_text
items[].visible_texts
items[].colors[].hex / proportion
items[].needs_confirmation
items[].knowledge_keys
warnings
knowledge_keys
result_source
schema_version
```

类别映射：

| 后端 | Swift 展示分类 |
|---|---|
| `eyeshadow_palette` | `CosmeticCategory.eyeshadow` / 眼影 |
| `eyeliner` | `CosmeticCategory.eyeliner` / 眼线 |
| `makeup_brush` | `CosmeticCategory.brush` / 毛刷 |

## 8. 演示账号缓存

固定映射：

| demo_asset_key | 图片 Asset | 降级 NSDataAsset |
|---|---|---|
| `demo_portrait_01` | `AvatarUserCutout` | `DemoVisualProfileSeed` |
| `demo_eyeshadow_palette_01` | `RecognizedEyeshadow` | `DemoEyeshadowSeed` |
| `demo_eyeliner_01` | `EyelinerProductIcon` | `DemoEyelinerSeed` |
| `demo_makeup_brush_01` | `PracticeToolIcon` | `DemoMakeupBrushSeed` |

物品识别读取顺序：

```text
有效 demo_results
-> queued/running 原 attempt + job_id
-> 使用原 request_id 继续上传或首次创建任务
-> 成功保存 demo_qwen_cache
-> 失败保存稳定错误码并保存 demo_fallback
```

缓存键包含账号、capability、asset key、真实图片 SHA-256、schema 版本、模型版本。
素材 SHA 或 dataset 版本变化会清除该素材旧尝试和旧结果；Qwen 缓存的 model ID
不匹配当前目标模型时不会命中。

## 9. SQLite migration

新增：

```text
vision_pending_jobs
demo_assets
demo_recognition_attempts
demo_results
```

关键字段保留 `request_id`、`job_id`、`asset_id`、状态、SHA、schema、model、
`result_source` 和标准 JSON。表中不保存 Token、API Key、上传签名 URL或供应商原始响应。

## 10. 日志边界

日志 category 为 `VisionPipeline`，只记录路由、AuraEye request/job/asset ID、标准状态、
缓存来源和稳定错误码。例如：

```text
Visual profile route=demo
Item recognition route=standard
Polled job=<AuraEye job id> status=running
Demo recognition cache hit asset=demo_eyeliner_01 source=demo_qwen_cache
Demo recognition fallback asset=demo_makeup_brush_01 code=network_unavailable
```

不记录 Token、对象存储签名 URL、供应商 file/task ID、供应商原始错误或结果 JSON。

## 11. 当前验证

- 四份演示 JSON 已通过 `jq` 语法校验。
- 全工程 Swift 文件已使用 iPhoneOS SDK 完成 `swiftc -typecheck`。
- 完整 `xcodebuild` 在当前环境被已有 Metal 文件所需的 Metal Toolchain，以及缺失的
  Simulator Runtime 阻断；排除 Metal 后 Swift 编译阶段可以启动，类型检查独立通过。
- 后端 Controller 尚未上线，普通账号网络行为需要后端完成后进行真机集成测试。
- 当前环境无法启动 Simulator，因此没有伪造普通账号或演示账号运行日志；代码已加入
  上述脱敏日志点，真机/可用模拟器运行后可直接导出。
