# AuraAye 沐瞳后端 API 接入指南

> 本文包含旧同步视觉接口，仅作历史参考。账号和图片异步接口请以 `前端账号与图片接口改造工作总结_NestJS后端接入版.md` 为准。

> **视觉接口更新：** 面部分析和化妆品识别已按“媒体资产 + 异步任务”改造。
> 本文中的两个同步 multipart 示例仅作旧版兼容说明；新后端应以
> `Swift视觉异步接口接入说明.md` 为准。

本文档对应当前 iOS 前端预留的五类远端能力：

0. 内部账号登录

1. 负一屏 AI 对话
2. 化妆品识别
3. 用户档案创建与虚拟分身生成
4. 妆容生成（包括上妆步骤文案）
5. 妆容推荐

当前 App 默认继续使用本地 Mock 和 SQLite。远端实现位于：

- `MakeupChat/Services/RemoteAPIService.swift`
- `MakeupChat/Services/AIAgentService.swift`
- `MakeupChat/Services/CosmeticsRecognitionService.swift`
- `MakeupChat/Services/FaceAnalysisService.swift`

## 0. 接口位置速查（文件 → Swift 语法 → HTTP）

| 能力 | 协议/数据边界 | 远端实现 | 当前调用入口 | HTTP |
|---|---|---|---|---|
| 内部账号登录 | `AuthenticationServicing.login(account:password:)`，位于 `Services/AuthenticationService.swift` | `RemoteAuthenticationService` | `LoginViewModel` / `LoginView` | `POST /v1/auth/login` |
| 负一屏聊天 | `AIAgentServicing.reply(to:)`，位于 `Services/AIAgentService.swift` | `RemoteAIAgentService`，位于 `Services/RemoteAPIService.swift` | `ViewModels/ChatViewModel.swift` 的 `agentService` | `POST /v1/chat/messages` |
| 化妆品识别 | `CosmeticsRecognitionServicing.recognize(image:categoryHint:)`，位于 `Services/CosmeticsRecognitionService.swift` | `RemoteCosmeticsRecognitionService` | `DisplayCabinetViewModel`、`OnboardingService` | `POST /v1/cosmetics/recognize` |
| 用户档案/面部分析 | `FaceAnalysisServicing.analyze(image:userId:)`，位于 `Services/FaceAnalysisService.swift` | `RemoteFaceAnalysisService` | `UserProfileSetupViewModel`、`OnboardingService` | `POST /v1/profiles/analyze` |
| 虚拟分身 | `VirtualAvatarGenerating.generateAvatar(from:)`，位于 `Services/FaceAnalysisService.swift` | 当前为本地透传；可独立增加远端实现 | `LocalFaceAnalysisService.avatarService` | 建议 `POST /v1/profiles/avatar` |
| 妆容生成/步骤文案 | `MakeupGenerationServicing.generate(context:)` | `RemoteMakeupGenerationService` | 尚未接入页面 ViewModel，接入点见第 9 节 | `POST /v1/makeup/generate` |
| 妆容推荐 | `MakeupRecommendationServicing.recommendations(context:)` | `RemoteMakeupRecommendationService` | 尚未接入首页 ViewModel，接入点见第 9 节 | `POST /v1/makeup/recommendations` |
| 真实天气 | `LiveWeatherProvider`，位于 `Services/LiveWeatherProvider.swift` | Apple `WeatherKit`，不经过业务后端 | `ContentView` 注入三个天气卡片 | Apple WeatherKit |

所有业务 API 的 HTTP 编码、Token、超时、统一响应解包都集中在
`Services/RemoteAPIService.swift` 的 `APIClient`。页面层不应直接创建
`URLSession`，否则错误处理、鉴权和响应格式会分散。

## 1. 总体约定

### 1.1 Base URL

建议为 Debug、TestFlight、Release 分别建立 `.xcconfig`：

```text
API_BASE_URL = https://api.example.com
```

然后在 target 的 Info 中增加：

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

开发联调可以临时配置 `API_ACCESS_TOKEN`。正式版本不要把长期密钥写入
Info.plist，应通过登录接口获取短期访问令牌并保存在 Keychain。

### 1.2 请求头

所有接口支持：

```http
Accept: application/json
Authorization: Bearer <access-token>
X-Request-ID: <uuid>
```

JSON 请求增加：

```http
Content-Type: application/json
```

图片请求使用：

```http
Content-Type: multipart/form-data; boundary=...
```

### 1.3 统一成功响应

所有接口统一返回：

```json
{
  "request_id": "7dc41698-7d06-40fc-9c88-d075fb16cfd4",
  "data": {}
}
```

`data` 的具体结构由各接口定义。

### 1.4 统一失败响应

非 2xx 状态码返回：

```json
{
  "code": "INVALID_IMAGE",
  "message": "图片中未识别到完整商品"
}
```

建议状态码：

- `400`：字段或图片无效
- `401`：令牌无效
- `413`：图片过大
- `422`：模型无法完成识别
- `429`：请求过于频繁
- `500`：服务内部错误
- `503`：模型服务暂不可用

## 1.5 内部测试账号登录

### 接口

```http
POST /v1/auth/login
Content-Type: application/json
```

请求：

```json
{
  "account": "auraye_test",
  "password": "用户输入的密码"
}
```

成功响应：

```json
{
  "request_id": "uuid",
  "data": {
    "user_id": "mrs_zhang",
    "display_name": "Mrs.Zhang",
    "access_token": "short-lived-access-token",
    "expires_at": "2026-08-04T14:00:00Z"
  }
}
```

iOS 接口和实现位置：

- `MakeupChat/Services/AuthenticationService.swift`
- `AuthenticationServicing.login(account:password:)`
- `RemoteAuthenticationService`，位于 `RemoteAPIService.swift`
- `LoginViewModel` / `LoginView`

登录成功后应使用返回的短期 Token 重新创建带鉴权的服务容器：

```swift
let bootstrap = try APIConfiguration.fromBundle()
let loginClient = APIClient(configuration: bootstrap)
let auth = RemoteAuthenticationService(client: loginClient)
let account = try await auth.login(account: inputAccount, password: inputPassword)

let authorizedServices = RemoteServiceContainer(
    configuration: APIConfiguration(
        baseURL: bootstrap.baseURL,
        accessToken: account.accessToken,
        timeout: bootstrap.timeout
    )
)
```

内部测试账号的后端数据必须通过 `user_id` 关联用户档案、化妆品、对话、妆容
推荐和上妆历史，不能仅在登录响应中返回一个静态首页对象。

## 2. 负一屏 AI 对话

### 接口

```http
POST /v1/chat/messages
Content-Type: application/json
```

请求：

```json
{
  "user_id": "mrs_zhang",
  "display_name": "Mrs.Zhang",
  "message": "我想要适合今天去公园的清透眼妆"
}
```

响应的 `data`：

```json
{
  "message": "今天适合低饱和蜜桃色眼妆，我已经为你整理好步骤。",
  "avatar_asset": "AvatarAI2"
}
```

iOS 对应实现：`RemoteAIAgentService`，符合 `AIAgentServicing` 协议。

接入示例：

```swift
let services = try RemoteServiceContainer(
    configuration: .fromBundle()
)
let viewModel = ChatViewModel(agentService: services.chat)
```

如果后续需要多轮上下文，可在请求中增加 `conversation_id`，并由后端保存消息
历史。不要把完整历史无限追加到每次请求中。

## 3. 化妆品识别

### 接口

```http
POST /v1/cosmetics/recognize
Content-Type: multipart/form-data
```

表单字段：

- `image`：JPEG 图片，必填
- `category_hint`：眼影、眼线或毛刷，可选，仅作为提示，不能覆盖模型识别结果

响应的 `data`：

```json
{
  "display_name": "某牌九色眼影盘",
  "category": "眼影",
  "tags": ["九色眼影", "日常大地色"],
  "color_hexes": ["#E8D6C3", "#CBA98E", "#A67C63"],
  "material": "细腻粉质",
  "summary": "九色组合，适合日常眼妆"
}
```

`category` 当前只允许：

- `眼影`
- `眼线`
- `毛刷`

iOS 对应实现：`RemoteCosmeticsRecognitionService`，符合
`CosmeticsRecognitionServicing` 协议。

识别成功后，前端会保存用户本次拍摄/选择的真实图片，并根据后端返回的
`category` 放入对应陈列柜分区。点击了哪个添加框不能决定最终分类。

接入 Onboarding：

```swift
let onboardingService = OnboardingService(
    recognitionService: services.cosmetics,
    faceAnalysisService: services.faceAnalysis
)
```

## 4. 用户档案创建与虚拟分身

### 接口

```http
POST /v1/profiles/analyze
Content-Type: multipart/form-data
```

表单字段：

- `image`：用户正脸照片，必填
- `user_id`：用户 ID，必填

响应的 `data`：

```json
{
  "avatar_base64": "<生成的虚拟分身 JPEG/PNG Base64，可为空>",
  "profile": {
    "faceShape": "鹅蛋脸",
    "skinTone": "粉皮（偏白）",
    "eyeShape": "杏眼",
    "recommendedStyle": "清透自然",
    "brushTip": "毛刷需要定期清洁"
  }
}
```

如果 `avatar_base64` 为空，前端会暂时使用用户上传照片作为档案头像。

iOS 对应实现：`RemoteFaceAnalysisService`，符合 `FaceAnalysisServicing`
协议。分析结果会继续保存到现有本地用户档案字段中，不影响当前 UI。

建议后端不要长期保存原始正脸照片；如果业务必须保存，需要：

- 明确用户授权与删除入口
- 使用对象存储私有桶
- 使用短期签名 URL
- 数据库仅保存对象 Key
- 设置自动过期与审计日志

## 5. 妆容生成与上妆步骤文案

### 接口

```http
POST /v1/makeup/generate
Content-Type: application/json
```

请求：

```json
{
  "user_id": "mrs_zhang",
  "profile": "{\"faceShape\":\"鹅蛋脸\",\"eyeShape\":\"杏眼\"}",
  "cosmetic_categories": ["眼影", "眼线", "毛刷"],
  "scene": "日常",
  "weather": "多云，26℃，紫外线偏弱"
}
```

响应的 `data`：

```json
{
  "id": "clear_sweet",
  "title": "清透甜美",
  "tag": "少女感",
  "summary": "适合日常出行，妆容简单，5分钟画完",
  "image_url": "https://cdn.example.com/look/clear-sweet.jpg",
  "color_hexes": ["#C87A72", "#CE8C80", "#DCADA0"],
  "steps": [
    {
      "id": 1,
      "title": "打底铺色",
      "tool": "大号铺色刷",
      "instruction": "少量多次铺色，覆盖眼皮暗沉和油脂。",
      "tip": "注意边缘自然晕染。",
      "preview_asset": null
    }
  ]
}
```

要求：

- `steps` 按实际执行顺序返回
- `id` 从 1 开始且不可重复
- `instruction` 是卡片中的完整上妆步骤文案
- `tip` 是页面底部小助手提示
- 色值必须是 `#RRGGBB`
- 后端必须根据用户真实拥有的化妆品生成步骤，不能推荐不存在的工具

iOS 对应协议与实现：

- `MakeupGenerationServicing`
- `RemoteMakeupGenerationService`
- `MakeupGenerationContext`
- `GeneratedMakeupPlan`
- `GeneratedMakeupStep`

## 6. 妆容推荐

### 接口

```http
POST /v1/makeup/recommendations
Content-Type: application/json
```

请求结构与 `/v1/makeup/generate` 相同。

响应的 `data` 是数组：

```json
[
  {
    "id": "clear_sweet",
    "title": "清透甜美",
    "tag": "少女感",
    "summary": "适合日常出行",
    "image_url": "https://cdn.example.com/look/clear-sweet.jpg",
    "color_hexes": ["#C87A72", "#CE8C80", "#DCADA0"],
    "steps": []
  }
]
```

首页当前展示三条推荐，因此建议后端返回 3 条。圆形色卡直接使用
`color_hexes` 中的绝对色值。

iOS 对应协议与实现：

- `MakeupRecommendationServicing`
- `RemoteMakeupRecommendationService`

## 7. 从本地 Mock 切换到远端

推荐在 App 根节点建立依赖容器：

```swift
let remote = try RemoteServiceContainer(
    configuration: .fromBundle()
)
```

然后分别注入：

```swift
ChatViewModel(agentService: remote.chat)

DisplayCabinetViewModel(
    recognitionService: remote.cosmetics
)

OnboardingService(
    recognitionService: remote.cosmetics,
    faceAnalysisService: remote.faceAnalysis
)
```

妆容生成和推荐的 ViewModel 接入时注入：

```swift
let generator: any MakeupGenerationServicing = remote.makeupGeneration
let recommender: any MakeupRecommendationServicing = remote.makeupRecommendation
```

在后端接口未稳定前，不建议直接删除本地实现。可以通过 Debug 配置或
Feature Flag 切换：

```swift
let useRemoteAPI = false
```

生产环境建议规则：

- 远端请求成功：展示远端结果并写入本地 SQLite 缓存
- 网络不可用：展示最近一次缓存
- 模型失败：提示用户重试，不要静默伪造识别结果
- 请求可取消：页面退出时取消未完成任务

## 8. 项目中的准确注入位置与语法

### 8.1 建议新增统一依赖容器

新建 `MakeupChat/Services/AppServices.swift`，不要在每个页面分别解析地址：

```swift
import Foundation

struct AppServices {
    let chat: any AIAgentServicing
    let cosmetics: any CosmeticsRecognitionServicing
    let faceAnalysis: any FaceAnalysisServicing
    let makeupGeneration: any MakeupGenerationServicing
    let makeupRecommendation: any MakeupRecommendationServicing

    static func remote() throws -> AppServices {
        let remote = RemoteServiceContainer(
            configuration: try APIConfiguration.fromBundle()
        )
        return AppServices(
            chat: remote.chat,
            cosmetics: remote.cosmetics,
            faceAnalysis: remote.faceAnalysis,
            makeupGeneration: remote.makeupGeneration,
            makeupRecommendation: remote.makeupRecommendation
        )
    }
}
```

正式环境不要使用 `try!`。App 启动时解析失败应明确显示“服务配置缺失”，
Debug 环境才回退到本地 Mock。

### 8.2 负一屏聊天注入

协议文件：`MakeupChat/Services/AIAgentService.swift`

```swift
protocol AIAgentServicing {
    func reply(to request: AIAgentRequest) async throws -> AIAgentResponse
}
```

调用文件：`MakeupChat/ViewModels/ChatViewModel.swift`

```swift
let viewModel = ChatViewModel(agentService: services.chat)
```

目前存在两个实际创建位置，接远端时两处都要替换，不能只改其中一处：

- `MakeupChat/Views/HomeView.swift`：首页内嵌负一屏的 `aiChatViewModel`
- `MakeupChat/Views/NegativeOneScreen01View.swift`：路由形式负一屏的 `viewModel`

推荐让这两个 View 的初始化器接收 `ChatViewModel`，不要在 View 内继续写
`ChatViewModel()` 默认实例。

### 8.3 化妆品识别注入

协议文件：`MakeupChat/Services/CosmeticsRecognitionService.swift`

```swift
let cabinetViewModel = DisplayCabinetViewModel(
    recognitionService: services.cosmetics
)

let onboardingService = OnboardingService(
    recognitionService: services.cosmetics,
    faceAnalysisService: services.faceAnalysis
)
```

实际 View 创建位置：

- `MakeupChat/Views/DisplayCabinetView.swift` 中的 `DisplayCabinetViewModel()`
- `MakeupChat/Views/FirstTimeUseView.swift` 中的 `FirstTimeUseViewModel`

后端返回的 `category` 是最终分栏依据，必须严格为 `眼影`、`眼线`、`毛刷`
之一。`category_hint` 只能帮助模型理解拍摄入口，不能覆盖识别结果。

### 8.4 用户档案和透明人物/虚拟分身注入

面部分析直接替换为：

```swift
let profileViewModel = UserProfileSetupViewModel(
    analysisService: services.faceAnalysis
)
```

实际 View 创建位置：

- `MakeupChat/Views/HomeView.swift` 的 `profileSetupViewModel`
- `MakeupChat/Views/UserProfileSetupView.swift` 的 `UserProfileSetupViewModel()`
- `MakeupChat/Services/OnboardingService.swift` 的 `faceAnalysisService`

若后端把“抠图分析”和“虚拟分身”拆成两个接口，实现
`VirtualAvatarGenerating` 后注入：

```swift
let analysis = LocalFaceAnalysisService(
    avatarService: RemoteVirtualAvatarService(client: remote.client)
)
```

透明人物必须返回 PNG（带 Alpha）；不要返回 JPEG。推荐响应返回对象存储
短期 URL，当前 `RemoteFaceAnalysisService` 也兼容 `avatar_base64`，但 Base64
会增加约三分之一传输体积，仅适合前期联调。

### 8.5 妆容生成和推荐接入页面

这两类协议和远端实现已经存在，但当前高保真页面仍读取
`MakeupLookCatalog` 本地测试数据。要真正展示远端数据，需要分别在：

- `HomeViewModel` 注入 `MakeupRecommendationServicing`，把响应映射到首页三张推荐卡
- `FirstTimeUseViewModel` 注入 `MakeupGenerationServicing`，Step 3 点击时发起生成
- `MakeupPreviewView` / `MakeupStepsView` 使用缓存的 `GeneratedMakeupPlan`

调用语法：

```swift
let context = MakeupGenerationContext(
    userId: user.userId,
    profileJSON: user.userFileJSON,
    cosmeticCategories: ["眼影", "眼线", "毛刷"],
    scene: "日常",
    weather: "多云，26℃，紫外线偏弱"
)

let recommendations = try await services.makeupRecommendation
    .recommendations(context: context)

let selectedPlan = try await services.makeupGeneration
    .generate(context: context)
```

页面只能在三类化妆品齐全后调用生成接口。`GeneratedMakeupPlan` 应先写入本地
缓存，再跳转预览页，这样网络波动和页面重建不会使步骤消失。

### 8.6 后端必须遵守的解码格式

客户端的 `APIClient.perform` 固定先解包 `APIEnvelope<T>`，因此成功响应必须是：

```json
{
  "request_id": "uuid",
  "data": { }
}
```

不能直接返回业务对象。例如 `/v1/chat/messages` 返回下面这种格式会解码失败：

```json
{ "message": "回复内容" }
```

必须返回：

```json
{
  "request_id": "uuid",
  "data": {
    "message": "回复内容",
    "avatar_asset": "AvatarAI2"
  }
}
```

字段采用 `snake_case`，日期采用 ISO-8601，色值采用 `#RRGGBB`。图片上传字段名
固定是 `image`。

### 8.7 本地 HTTP 联调注意事项

模拟器访问 Mac 本机服务可以使用 `http://127.0.0.1:<port>`。如果使用 HTTP，
Debug 阶段需要配置 ATS 例外；正式环境必须使用 HTTPS。真机不能用
`127.0.0.1` 访问 Mac，需要使用同一局域网内 Mac 的 IP 或测试域名。

建议先按顺序联调：聊天 JSON → 化妆品 multipart → 档案 multipart → 妆容生成
→ 首页推荐。每个接口先用 `curl` 验证响应包裹格式，再接入页面。

## 9. 联调检查清单

- Base URL 使用 HTTPS
- Token 不硬编码进 Git
- 图片上传限制尺寸和 MIME Type
- 服务端统一返回 `request_id`
- 客户端日志不打印人脸 Base64、Token 或完整档案
- 化妆品分类只能由识别结果决定
- 三类化妆品齐全后才能调用妆容生成
- 色值符合 `#RRGGBB`
- 所有步骤均包含标题、工具、文案和提示
- 429、超时和 5xx 均有可理解的重试提示
- 真机测试相机、相册、弱网和后台恢复
