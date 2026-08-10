# AuraEye iPhone 相册演示流程前端执行与验收报告

> 对照文档：`08_iPhone相册演示流程前端执行文档(1).md`（v1.2，2026-08-10）  
> 执行日期：2026-08-10  
> 工程：MakeupChat / SwiftUI / iOS

## 1. 执行结论

本次已完成 v1.2 要求的前端架构替换：测试账号与普通账号共用 `OfficialGalleryView`、`SelectedPhoto`、`VisionJobService`、Job 轮询及现有结果页面；账号差异只由 `/auth/me` 的 `features.gallery_mode` 决定相册数据源。

已删除旧的 `/demo/fixtures/resolve`、媒体上传意图、demo 专用业务 Repository、前端图片哈希和 demo 结果缓存路径。人像分析、物品识别及 `makeup_render` 的任务创建统一为 `POST /vision/jobs`，轮询统一为 `GET /vision/jobs/{job_id}`。

2026-08-10 补充资源验收：已使用 `auraeye-frontend-canonical-demo-fixtures-v1.2.zip` 中的四张 canonical 演示图替换 `DemoFixtures` 内同名资源，并保持 manifest 指定的标准资源名。测试账号真机相册不再存在“演示图片资源不完整”的前端资源阻塞。

- `demo_tool_brush_set_001.jpg`
- `demo_cosmetic_eyeliner_001.jpg`
- `demo_face_portrait_001.jpg`
- `demo_cosmetic_eyeshadow_palette_001.jpg`

已确认工程内四张资源与 canonical 压缩包解出文件 SHA-256 完全一致。压缩包内刷子、眼线、眼影三张文件扩展名为 `.jpg`，实际字节格式为 PNG；本次按 canonical 包原样替换，没有做二次转码。`face` 资源为 JPEG。

## 2. 工程基线

| 项目 | 当前值 |
|---|---|
| Xcode | 26.6（17F113） |
| Apple Swift Toolchain | 6.3.3 |
| 工程 Swift Language Mode | Swift 5.0 |
| iOS Deployment Target | iOS 17.0 |
| API Base URL（Debug） | `https://api-dev.peterhigh.xyz/v1` |

## 3. 账号 feature 与相册路由

新增稳定枚举：

```swift
enum GalleryMode: String, Codable, Sendable {
    case fixedDemo = "fixed_demo"
    case authorizedLibrary = "authorized_library"
}
```

`AccountFeatures` 当前字段：

| Swift 字段 | JSON 字段 | 类型 |
|---|---|---|
| `galleryMode` | `gallery_mode` | `fixed_demo` / `authorized_library` |
| `useDemoAssets` | `use_demo_assets` | `Bool` |
| `allowLiveRecognitionSeed` | `allow_live_recognition_seed` | `Bool` |

远端登录成功后使用新 access token 请求 `GET /auth/me`，并以返回的 `features` 覆盖登录响应中的临时 feature。相册路由只检查 `galleryMode`：

```text
fixed_demo          -> DemoBundlePhotoSource
authorized_library  -> AuthorizedPhotoKitSource
```

没有用户名字符串判断。未知 `gallery_mode` 会在 Codable 解码阶段失败，无法进入相册。

## 4. 相册与原图读取

新增统一应用内相册：

- 使用 SwiftUI NavigationStack、三列 PhotoKit 风格网格、系统选中态、取消、加载、空状态和错误状态；
- Limited Photo Library 状态提供“管理可访问照片”；
- 普通账号只通过 `PHAsset.fetchAssets` 读取当前授权范围；
- 缩略图使用 `PHCachingImageManager`；
- 提交时使用 `PHAssetResourceManager.requestData` 重新读取所选资产数据，不提交缩略图；
- 测试账号通过 manifest 恰好声明四张 Bundle JPEG，并用 `Data(contentsOf:options:.mappedIfSafe)` 返回原始字节；
- 没有裁剪、滤镜、编辑、旋转、截图或重新 JPEG 编码步骤；相机输入在没有文件原始字节时才编码一次。

原有“拍照/从相册选择”入口及页面交互保留，“从相册选择”内部呈现方式替换为统一 `OfficialGalleryView`。修改入口包括：首页人像、首次使用流程、人像档案创建、档案重传、陈列柜物品识别。

`NSPhotoLibraryUsageDescription` 已更新为：

```text
需要读取您授权的照片，用于人像分析、商品识别与试妆。
```

## 5. 统一视觉任务接口

任务创建：

```http
POST /v1/vision/jobs
Authorization: Bearer <access_token>
Idempotency-Key: <stable-key>
Content-Type: multipart/form-data; boundary=<boundary>
```

multipart 字段：

| 字段 | 必填 | 前端实现 |
|---|---|---|
| `request_id` | 是 | 当前操作稳定 request ID；未完成任务恢复时复用 |
| `capability` | 是 | `face_analysis` / `item_recognition` / `makeup_render` |
| `image` | 是 | `SelectedPhoto.loadOriginalData()` 返回的字节 |
| `options` | 否 | 类型安全模型编码后的 JSON 字符串 |

`face_analysis` options 使用 `consent_version`；`item_recognition` options 使用 `recognition_scope.allowed_categories` 与 `recognition_scope.max_items`；`makeup_render` options 使用 `recipe_id`。成功响应只接受标准 `{request_id,data:{...}}` Envelope，不再兼容直接 Job DTO，随后只轮询：

```http
GET /v1/vision/jobs/{job_id}
```

Job 恢复表只保留 account、capability、request/idempotency key、job ID、状态及安全响应元数据；已移除 `asset_id`、`input_sha256` 和三张 demo 缓存表。前端结果 DTO 不读取 Provider、fixture hash、缓存来源或服务端文件路径。

原有 `/makeup/generate` 和 `/makeup/recommendations` 仍用于非图片型妆容方案/推荐，不属于本次视觉图片任务；所有图片型视觉任务均进入 `/vision/jobs`。

## 6. 错误与降级策略

保留 Problem Details 解码、Job 超时、429/503 `Retry-After` 和一次 401 刷新挂钩。新增并冻结以下 demo 错误映射：

- `DEMO_FIXTURE_NOT_RECOGNIZED`
- `DEMO_FIXTURE_MISMATCH`
- `DEMO_CACHE_NOT_READY`
- `DEMO_VARIANT_NOT_FOUND`
- `PAYLOAD_TOO_LARGE`
- `UNSUPPORTED_MEDIA_TYPE`

demo 业务错误直接停止当前任务，不调用第二个上传接口、不切换普通流程、不触发 Provider seed。

## 7. 主要文件变更

新增：

- `MakeupChat/Features/PhotoGallery/PhotoSource.swift`
- `MakeupChat/Features/PhotoGallery/OfficialGalleryViewModel.swift`
- `MakeupChat/Features/PhotoGallery/OfficialGalleryView.swift`
- `MakeupChat/Repositories/VisionJobPersistence.swift`
- `MakeupChat/Resources/DemoFixtures/demo-gallery-manifest.json`
- `MakeupChatTests/PhotoSourceRoutingTests.swift`
- `MakeupChatTests/DemoBundlePhotoSourceTests.swift`
- `MakeupChatTests/VisionJobServiceTests.swift`
- `MakeupChatTests/DemoProviderFallbackTests.swift`

删除：

- `MakeupChat/Repositories/DemoVisionRepository.swift`
- 旧 `DemoFixtureResolverTests.swift`

重点修改：

- `AuthenticationService.swift`、`SessionContext.swift`：`gallery_mode` 与服务端 feature 路由；
- `RemoteAPIService.swift`、`VisionInfrastructure.swift`：统一 multipart 和 `/vision/jobs`；
- `VisualProfilePipeline.swift`、`ItemRecognitionPipeline.swift`：移除 demo/standard 双 Provider，统一任务创建与轮询；
- `Schema.swift`、`DatabaseManager.swift`：迁移至 v3 Job 恢复表并删除 demo 缓存表；
- 五个相册入口 View 及对应 ViewModel/Service：传递 `VisionImageInput` 原始字节；
- `project.pbxproj`、共享 scheme：新增源码、测试 target 与资源构建规则。

未修改 Shader 源码、动态背景逻辑、页面视觉样式及既有导航结构。

## 8. 构建与测试结果

| 检查项 | 结果 | 说明 |
|---|---|---|
| `project.pbxproj` lint | 通过 | `plutil -lint` 返回 OK |
| 主工程全部 Swift 源码 typecheck | 通过 | iPhoneOS 26.5 SDK / arm64 / iOS 17 |
| 测试 target build-for-testing | 通过 | 四个测试文件均编译、链接成功 |
| 完整 Debug/Release Xcode build | 环境阻塞 | 本机缺少 Metal Toolchain，且 Simulator Runtime 服务不可用；Shader 未被修改 |
| XCTest 实际执行 | 环境阻塞 | 当前机器没有可用 iOS Simulator Runtime |
| Debug 资源复制规则 | 通过 | `DemoFixtures` 现包含 manifest 与四张标准命名 JPEG |
| Release 排除规则 | 通过 | Release `EXCLUDED_SOURCE_FILE_NAMES = DemoFixtures`；构建产物目录未发现 `DemoFixtures`、manifest 或 `demo_*.jpg` |

为隔离本机缺失的 Metal/Simulator 组件，编译验收使用命令行临时排除 `SharedFluidBackground.metal` 与 `Assets.xcassets`；这只是验收命令覆盖，没有改动工程 Shader/Assets 配置。完整构建仍应在安装 Metal Toolchain 与 iOS Simulator Runtime 的 Xcode 环境再执行一次。

自动化测试覆盖：

- 两个合法 gallery mode 解码、未知值失败；
- feature 只切换 PhotoSource 类型；
- 临时四 JPEG 数据源恰好返回四项且原始字节不变；
- 三种 capability 使用相同 `/v1/vision/jobs`、相同 multipart DTO 和原始图片字节；
- demo 错误只产生一次 `/v1/vision/jobs` 请求，不 fallback。

## 9. Release 隐私证明

Release target 已配置：

```text
EXCLUDED_SOURCE_FILE_NAMES = DemoFixtures
```

Release 构建启动后检查：

```text
/tmp/makeup-chat-release-derived/Build/Products/Release-iphoneos/MakeupChat.app
```

其中未找到 `DemoFixtures`、`demo-gallery-manifest.json` 或 `demo_*.jpg`。正式 Archive 后仍建议再次解包 `.app` 执行同样检查。

## 10. 后续真机联调前必须完成

1. 安装 Xcode Metal Toolchain 与可用 iOS Simulator Runtime，执行完整 Debug、Release build 和 XCTest。
2. 用 `aurayetest` 验证 `/auth/me.features.gallery_mode = fixed_demo`，相册恰好四张；用普通账号验证 `authorized_library` 及 Limited Photos 管理入口。
3. 公网抓取脱敏请求，确认两类账号均只有 `POST /v1/vision/jobs` 和 `GET /v1/vision/jobs/{job_id}`，并完成三种 capability 的结果页联调。
