# AuraEye 前端两轮改造与 Node.js 后端执行清单

> 更新时间：2026-08-06  
> 客户端：SwiftUI / iOS 17+  
> 后端：Node.js，推荐 Express 或 NestJS  
> 视觉契约：`v1`，Schema：`1.0`

## 1. 两轮改造结论

本文件合并记录以下两轮工作，并作为后续后端实施的唯一交接文档：

1. 第一轮：登录会话、正式账号视觉上传、异步任务、演示账号缓存和 SQLite 持久化。
2. 第二轮：恢复全局 Metal shader 动态背景；改为用户从系统相册选图后，再判断是否命中演示缓存。

当前前端已完成：

- 登录响应兼容嵌套 `user` 和旧扁平结构。
- 使用 `account_mode` 和 `features` 做集中能力路由，页面不判断用户名。
- 正式图片走“申请上传 → 对象存储直传 → 完成上传 → 创建任务 → 轮询结果”。
- 演示账号仍必须由用户打开系统相册并主动选图。
- 所选图片与人像、眼影、眼线或工具演示素材视觉一致时，读取对应缓存。
- 未匹配演示素材时，按正式视觉接口处理，不错误套用演示结果。
- 异步任务的 `request_id`、`asset_id`、`job_id` 和终态会持久化。
- 首页及适用页面重新显示原有 Metal shader 动态背景，shader 算法未更改。

## 2. 第二轮前端行为变更

### 2.1 动态背景

问题根因是 SwiftUI shader 包装视图文件缺失，根视图虽然仍在调用背景，但没有可用的正确实现。

修复内容：

- 恢复 `AppDynamicBackgroundView`。
- 保留 `SharedFluidBackground.metal` 内的 `sharedFluidBackground` 算法，不修改颜色或运动逻辑。
- shader 输入改用不透明白色矩形，保证 shader 返回的 alpha 不为 0。
- 使用 `TimelineView` 持续传入时间，页面活跃时约 30 FPS。
- Metal 文件仍属于 App Target 的 Sources Build Phase。

该项不需要后端配合。

### 2.2 演示图片缓存判断

新流程：

```text
用户点击上传
  → 打开系统相册/相机
  → 用户主动选择图片
  → 客户端标准化图片方向和尺寸
  → 与四个内置演示素材计算视觉指纹
      → 命中：按对应 demo_asset_key 读取 SQLite 缓存
      → 未命中：进入正式上传与异步识别流程
```

不再根据“测试账号 + 页面入口”自动注入图片，也不再仅凭用户选择的分类判断缓存。

图片匹配使用以下信息：

- 9×8 灰度差异哈希（dHash）；
- 8×8 平均 RGB；
- 宽高比；
- 自动消除 `UIImage` 方向差异。

这样可容忍系统相册导出时的 JPEG 重压缩和元数据变化，但裁剪、明显调色或不同图片不会命中。视觉指纹仅用于本地演示缓存路由，不上传后端，也不能作为安全或身份认证依据。

演示素材映射：

| `demo_asset_key` | 类型 | 图片 Asset | 缓存结果 |
|---|---|---|---|
| `demo_portrait_01` | 人像 | `AvatarUserCutout` | `DemoVisualProfileSeed` |
| `demo_eyeshadow_palette_01` | 眼影 | `RecognizedEyeshadow` | `DemoEyeshadowSeed` |
| `demo_eyeliner_01` | 眼线 | `EyelinerProductIcon` | `DemoEyelinerSeed` |
| `demo_makeup_brush_01` | 工具 | `PracticeToolIcon` | `DemoMakeupBrushSeed` |

## 3. 账号与登录接口

### 3.1 登录

```http
POST /v1/auth/login
Content-Type: application/json
```

请求：

```json
{
  "username": "aurayetest",
  "password": "******"
}
```

推荐响应：

```json
{
  "request_id": "req_login_01",
  "data": {
    "access_token": "access-token",
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

字段要求：

| 字段 | 类型 | 必需 | 说明 |
|---|---|---:|---|
| `access_token` | string | 是 | API Bearer Token |
| `refresh_token` | string | 建议 | 刷新凭据 |
| `access_token_expires_at` | ISO 8601 | 建议 | Token 到期时间 |
| `user.id` | string | 是 | 稳定用户 ID |
| `user.account_mode` | `demo` / `standard` | 是 | 客户端能力路由依据 |
| `features.use_demo_assets` | boolean | 是 | 是否允许本地演示素材缓存 |
| `features.allow_live_recognition_seed` | boolean | 是 | 演示素材首次无缓存时是否允许远端识别一次 |

兼容期前端仍能解析 `user_id`、`username`、`display_name`、`expires_at` 等旧扁平字段，但后端应尽快统一为上述结构。

## 4. 媒体上传接口

### 4.1 创建上传意图

```http
POST /v1/media/upload-intents
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "request_id": "req_upload_uuid",
  "file_name": "portrait.jpg",
  "content_type": "image/jpeg",
  "file_size": 2451021,
  "purpose": "vision"
}
```

响应 `data`：

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

### 4.2 上传二进制

客户端直接请求 `upload_url`，方法由 `upload_method` 指定。只携带 `upload_headers`，不得把 AuraEye Bearer Token 转发给对象存储。

### 4.3 标记上传完成

```http
POST /v1/media/assets/{asset_id}/complete
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "request_id": "req_upload_uuid"
}
```

后端应校验对象存在、大小和 MIME，完成后才允许创建视觉任务。

## 5. 面部分析异步接口

### 5.1 创建任务

```http
POST /v1/vision/profile-jobs
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "request_id": "req_profile_uuid",
  "asset_id": "asset_uuid",
  "consent_version": "visual-analysis-v1"
}
```

### 5.2 成功结果字段

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
result_source
schema_version
```

`profile_snapshot` 子字段允许后端扩展 JSON 值；`narrative_status` 失败时仍应返回已完成的结构化结果。

## 6. 物品识别异步接口

### 6.1 创建任务

```http
POST /v1/vision/item-recognition-jobs
Authorization: Bearer <token>
Content-Type: application/json
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

### 6.2 成功结果字段

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
items[].colors[].hex
items[].colors[].proportion
items[].needs_confirmation
items[].knowledge_keys
warnings
knowledge_keys
result_source
schema_version
```

分类枚举必须使用：`eyeshadow_palette`、`eyeliner`、`makeup_brush`。识别结果在前端仍会进入确认卡，用户确认后才写入化妆品柜。

## 7. 通用任务响应与查询

创建任务返回：

```json
{
  "request_id": "req_item_uuid",
  "data": {
    "job_id": "job_uuid",
    "request_id": "req_item_uuid",
    "job_type": "item_recognition",
    "asset_id": "asset_uuid",
    "status": "queued",
    "progress": {
      "stage": "queued",
      "poll_after_ms": 800
    }
  }
}
```

查询：

```http
GET /v1/vision/jobs/{job_id}
Authorization: Bearer <token>
```

状态仅允许：

```text
queued | running | succeeded | failed | timed_out | cancelled
```

成功时 `data.result` 为对应能力 DTO；失败时建议返回：

```json
{
  "request_id": "req_item_uuid",
  "error": {
    "code": "VISION_PROVIDER_UNAVAILABLE",
    "message": "provider temporarily unavailable",
    "retryable": true
  }
}
```

后端必须保证：

- 同一用户、同一能力、同一 `request_id` 幂等；重复创建返回原任务。
- `job_id` 全局唯一且不可猜测。
- 查询任务时校验任务所有权。
- `poll_after_ms` 建议 250～5000；客户端最长主动等待 90 秒。
- 所有终态不可回退到运行态。
- 图片与任务日志不得记录原始二进制、签名 URL 或 Token。

## 8. 演示账号缓存状态机

命中演示图片后，前端按以下顺序处理：

```text
有效 demo_results
  → 直接返回缓存
否则读取 demo_recognition_attempts
  → succeeded：读取结果
  → queued/running/uploaded：恢复原 job_id
  → failed/timed_out/cancelled：使用 Bundle 标准 DTO，不自动重试
否则
  → allow_live_recognition_seed=false：使用 Bundle 标准 DTO
  → allow_live_recognition_seed=true：创建一次远端任务并缓存结果
```

缓存失效条件：`asset_sha256`、`dataset_version`、`schema_version` 或 `model_version` 变化。

客户端 SQLite 表：

| 表 | 用途 |
|---|---|
| `demo_assets` | 演示素材、SHA、数据集版本、远端 asset ID |
| `demo_recognition_attempts` | 每素材最多一次的识别尝试和 job 状态 |
| `demo_results` | 标准 DTO JSON 缓存 |
| `vision_pending_jobs` | 正式账号未完成任务恢复 |

人像命中时直接读取 `DemoVisualProfileSeed`，不调用远端 profile job。物品命中时才适用一次识别与降级状态机。未命中的图片始终按正式流程走后端。

## 9. Node.js 推荐分层

```text
src/
  modules/
    auth/
    media/
    vision/
      profile/
      item-recognition/
      jobs/
  providers/
    object-storage/
    qwen/
  workers/
    vision.worker.ts
  common/
    auth/
    idempotency/
    errors/
    validation/
```

推荐职责：

- Controller：鉴权、参数校验、返回统一 envelope。
- Service：业务状态机、幂等、任务所有权。
- Queue/Worker：调用 Qwen 等模型，写入任务进度和标准化结果。
- Provider Adapter：隔离不同模型厂商字段，禁止把供应商响应直接返回 Swift。
- Repository：事务写入 media asset、job、result 和 idempotency key。

可用 Express + Zod，也可用 NestJS + class-validator；队列可用 BullMQ + Redis。数据库至少需要唯一约束：

```text
UNIQUE(user_id, job_type, request_id)
```

## 10. 后端执行顺序

1. 先完成登录响应中的 `account_mode` 和 `features`。
2. 完成三个媒体端点，并验证对象存储签名上传。
3. 建立通用 `vision_jobs` 表、幂等约束和查询接口。
4. 接入 profile worker，输出稳定的 `profile_snapshot` DTO。
5. 接入 item recognition worker，完成分类与颜色字段标准化。
6. 增加鉴权、任务所有权、超时、失败码和结构化日志。
7. 用 standard 和 demo 两类账号联调。

## 11. 联调验收清单

- standard 账号选任意相册图：成功上传、建任务、轮询并显示结果。
- demo 账号选与内置人像相同的相册图：本地命中，不创建 profile job。
- demo 账号分别选眼影、眼线、工具相同图：命中正确 key，不依赖入口分类。
- demo 账号选其他图片：调用正式后端，不返回错误的演示缓存。
- 杀掉 App 后重进：已有 `job_id` 继续查询，不重复创建任务。
- 同一 `request_id` 重复提交：后端返回同一个任务。
- Token 失效、403、429、5xx、供应商超时均返回统一错误结构。
- 首页和需要动态背景的页面显示流动 shader，不是纯白；进入后台时可暂停时间线。

## 12. 本轮前端验证结果

- Swift 全量 `swiftc -typecheck`：通过，0 错误。
- Xcode 工程文件与 entitlements：`plutil` 通过。
- 四组演示 JSON 数据：`jq` 校验通过。
- `SharedFluidBackground.metal` 与 `GradientBackgroundView.swift` 均在 Target Sources。
- 当前执行环境缺少 Metal Toolchain 和 iOS Simulator Runtime，因此无法在此处完成 simulator 运行截图；需在本机 Xcode 安装对应组件后做最后一轮真机或模拟器视觉验收。

## 13. 前端主要文件

| 内容 | 文件 |
|---|---|
| 动态 shader 包装视图 | `MakeupChat/Components/GradientBackgroundView.swift` |
| Metal shader | `MakeupChat/SharedFluidBackground.metal` |
| 登录与 AccountMode | `MakeupChat/Services/AuthenticationService.swift` |
| 集中 SessionContext | `MakeupChat/Services/SessionContext.swift` |
| 上传、任务和轮询 DTO | `MakeupChat/Services/VisionInfrastructure.swift` |
| API 与对象存储上传 | `MakeupChat/Services/RemoteAPIService.swift` |
| 面部分析路由 | `MakeupChat/Services/VisualProfilePipeline.swift` |
| 物品识别路由 | `MakeupChat/Services/ItemRecognitionPipeline.swift` |
| 演示图片匹配与 SQLite | `MakeupChat/Repositories/DemoVisionRepository.swift` |
| SQLite Schema | `MakeupChat/Database/Schema.swift` |

