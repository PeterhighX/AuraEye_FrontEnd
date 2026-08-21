# 负一屏 Hermes 对话联调审计与契约汇总

审计日期：2026-08-21  
审计对象：`MakeupChat` iOS 前端当前 `main`（HEAD `e32bbea`）  
用途：部署联调前，供 iOS、NestJS/API、Hermes/Agent、测试与运维共同冻结范围和契约。

> 本文以当前 Swift 代码为事实源。文中的“建议契约”是待前后端确认的联调基线，不代表 NestJS 或 Hermes 已经实现。

## 1. 一句话结论

负一屏聊天 UI 和纯本地演示链路已经可运行、可编译，但生产页面仍默认使用 `LocalAIAgentService`。现有 `RemoteAIAgentService` 只是一个未注入页面的单轮 REST 适配器；会话、多轮上下文、图片上传、Hermes 工具事件、消息级失败/重试、流式响应和妆容生成完成跳转都尚未形成真实远端闭环。

因此，当前状态应定义为：

```text
UI 演示完成 + 本地 SQLite 演示完成 + 单轮远端适配器预留
≠ Hermes 对话已接入
≠ 图片/妆容生成链已接入
≠ 可直接开始端到端联调
```

## 2. 审计口径与验证结果

- 静态核对了 View、ViewModel、Service、Repository、Model、SQLite Schema、登录会话、API Client、Xcode 配置及现有接口文档。
- 搜索了所有生产代码中的聊天创建点和 `RemoteAIAgentService` 使用点。
- 运行了无签名 Debug Simulator 构建：`BUILD SUCCEEDED`。
- 当前 `MakeupChatTests` 没有聊天 ViewModel、会话、消息契约或远端聊天测试。
- `docs/20_phase_2_backend_api/13_前后端接口台账.md` 已明确：`/chat/messages` 尚无已确认 NestJS Controller，不得当作已上线接口调用。

## 3. 当前聊天相关文件结构

### 3.1 当前生产代码

```text
MakeupChat/
├─ ContentView.swift                         # 根 Tab/NavigationStack
├─ Models/
│  ├─ AppRoute.swift                        # .aiChat / .makeupPreview 等路由
│  ├─ AppSession.swift                      # isAIChatPresented、妆容流程内存状态
│  └─ ChatMessage.swift                     # UserProfile、ChatMessage、kind/sender
├─ Views/
│  ├─ HomeView.swift                        # 首页同层负一屏入口；自建 ChatViewModel
│  ├─ NegativeOneScreen01View.swift         # 路由入口；自建 ChatViewModel
│  ├─ NegativeOneScreen02View.swift         # 键盘态包装/预览
│  └─ ChatConversationView.swift            # 消息列表、滚动、输入、选图、生成占位
├─ ViewModels/
│  └─ ChatViewModel.swift                   # 当前聊天编排与页面状态
├─ Components/
│  ├─ MakeupInputBar.swift                  # 文本、发送、相机、加号
│  ├─ ChatBubbleView.swift                  # 文本/本地图气泡
│  ├─ SuggestionChipsView.swift             # 两个固定建议词
│  ├─ TipBarView.swift                      # 静态 TipLibrary 轮播
│  ├─ CameraPickerView.swift                # UIImagePickerController
│  └─ LocalImageView.swift                  # 本地相对路径图片
├─ Services/
│  ├─ AIAgentService.swift                  # AIAgentServicing + Local 实现
│  ├─ ChatSessionService.swift              # 纯本地消息/图片/演示回复
│  ├─ RemoteAPIService.swift                # APIClient + 未注入的 RemoteAIAgentService
│  ├─ AuthenticationService.swift           # 登录与 APIEnvironment 初始化
│  └─ SessionContext.swift                  # 当前 token/user 上下文
├─ Repositories/
│  ├─ ChatRepository.swift                  # SQLite 消息查询/插入/图片挂载
│  └─ UserRepository.swift                  # 当前取“最近更新的本地用户”
├─ Database/
│  ├─ Schema.swift                          # chat_messages 表
│  └─ DatabaseSeeder.swift                  # mrs_zhang 与欢迎消息种子
├─ Storage/
│  └─ LocalMediaStore.swift                 # 本地 JPEG/PNG/路径管理
└─ Supporting/
   └─ Info.plist                            # AURAEYE_API_BASE_URL
```

### 3.2 当前相关文档

```text
docs/20_phase_2_backend_api/13_前后端接口台账.md  # 现网/联调事实台账，优先级最高
后端API接入指南.md                              # 历史单轮接口接入说明
完整后端API接口文档.md                         # 全量规划，含 conversation/messages 设计
本文                                           # 本次负一屏专项审计与建议契约
```

历史文档不能单独作为已上线证明。接口事实优先级建议继续采用：后端 Controller/DTO/测试 > Swift 实际调用 > OpenAPI > 历史规划文档。

## 4. 已完成工作清单

### 4.1 页面与交互

| 能力 | 当前实现 | 状态 |
| --- | --- | --- |
| 首页进入负一屏 | `HomeView` 同层水平转场 | 已完成（本地） |
| 路由进入负一屏 | `AIChatRouteView` | 已完成（存在第二创建点） |
| 返回/滑动退出 | 两个入口分别实现动画与手势 | 已完成 |
| 消息列表 | 本地 SQLite 加载，按时间升序 | 已完成（仅本地） |
| 初始欢迎语 | Seeder/空会话自动插入 | 已完成（固定文案） |
| 文本输入与发送 | 键盘 Send、发送按钮、空文本拦截 | 已完成 |
| 建议词 | “更清新”“正式一点” | 已完成（固定值） |
| 相机/相册 | 系统 Picker，二者目前走同一个选择弹窗 | 已完成（选图层） |
| 图片气泡 | 图片写 Documents，本地相对路径展示 | 已完成（仅本地） |
| 自动滚动/键盘焦点 | 新消息滚底、AI 回复后收键盘 | 已完成 |
| AI 思考占位 | 临时 `generating` 消息 | 已完成（演示语义） |
| 生成图揭示动画 | 固定 3 秒后显示本地素材 | 已完成（演示动画） |

### 4.2 数据与服务

| 能力 | 当前实现 | 状态 |
| --- | --- | --- |
| 消息本地持久化 | `chat_messages` + `ChatRepository` | 已完成 |
| 用户消息先落库 | `persistUserText` | 已完成 |
| AI 回复落库 | `persistAIResponse` | 已完成 |
| 图片挂到最近固定文案 | SQL 精确匹配指定中文文本 | 已完成（脆弱演示逻辑） |
| Agent 抽象 | `AIAgentServicing.reply` | 已完成（粒度仅单轮文本） |
| 本地 Agent | 关键词匹配 + 900ms 延迟 | 已完成（Mock） |
| 远端 Agent 适配器 | `POST /chat/messages` | 已编码，未注入、未确认后端可用 |
| HTTP 公共层 | Envelope、Bearer、401 刷新一次、Problem Details | 已完成并被其他业务使用 |
| API Base URL | Debug/Release 均为 `https://api-dev.peterhigh.xyz/v1` | 已配置 |

## 5. 当前真实状态模型

### 5.1 View 层状态

| 状态 | 用途 | 风险/备注 |
| --- | --- | --- |
| `isInputFocused` | 键盘与建议词显隐 | 可用 |
| `showImagePicker` | 系统图片选择器 | 可用 |
| `showImageSourcePicker` | 来源弹窗 | 可用 |
| `imageSource` | 相机/相册类型 | 可用 |
| `assistantCountWhenOpeningPicker` | 判断取消后是否恢复焦点 | 通过“AI 消息数量”间接判断，远端并发后不可靠 |
| `generatedImageReveal` | 生成图模糊揭示 | 整个 View 共用，多个 generating 消息会相互影响 |
| `isGenerationFinished` | 固定 3 秒进度 | 不是后端任务状态 |

### 5.2 ViewModel 层状态

| 状态 | 当前变化路径 | 结论 |
| --- | --- | --- |
| `user` | 从 SQLite 最近更新用户加载 | 未绑定登录 token 的用户 ID |
| `messages` | SQLite 全量 reload + 临时 thinking | 无分页、无服务端合并 |
| `inputText` | 输入/建议词/发送清空 | 可用 |
| `isLoading` | 整个聊天页单一布尔锁 | 无法表达上传、发送、流式、工具调用等并行阶段 |
| `tipText` | 从本地 CosmeticsRepository 读取 | `ChatConversationView` 实际使用 `TipBarView()`，该值没有被展示 |
| `isMakeupReady` | 仅声明，代码中从未设为 `true` | `onMakeupReady` 与跳转链为死链 |

### 5.3 消息模型

当前仅有：

- `sender`: `ai | user`
- `kind`: `text | photo | generating | eyePreview`
- `text`、单个本地图片/Asset、头像 Asset、创建时间

当前缺少：

- `conversation_id`、服务端 `message_id`、`client_message_id`
- `status`（queued/sending/sent/streaming/failed/cancelled）
- 失败码、可重试标志、重试次数、服务端 request ID
- 多附件、远端媒体 ID/URL/MIME/尺寸
- Hermes run/tool call/action/plan 关联 ID
- 消息版本、编辑/撤回、引用、分页游标

## 6. 当前事件链

### 6.1 进入与加载

```text
首页 AI 入口
  → HomeView.showsAIChat = true
  → ChatConversationView.onAppear
  → ChatViewModel.reload()
  → UserRepository.currentUser()（取本地最近更新用户）
  → ChatRepository.fetchMessages(userId)
  → 本地列表展示
```

另一条 `.aiChat → AIChatRouteView` 路由也会新建独立 `ChatViewModel`。两个入口没有共享依赖容器，也没有共享远端 conversation 状态。

### 6.2 普通文字发送

```text
发送按钮/键盘/建议词
  → trim + !isLoading
  → 用户消息写本地 SQLite
  → 全量 reload
  → 内存追加 generating 占位
  → agentService.reply(userId, displayName, message)
     当前实际为 LocalAIAgentService
  → AI 回复写本地 SQLite
  → 全量 reload（占位被移除）
```

异常时只删除 `generating`，错误被吞掉；用户消息已经持久化，但没有失败标记或重试入口。

### 6.3 固定“公园图片”文本

```text
发送精确包含固定文案的文本
  → 用户消息写本地 SQLite
  → 直接 return，不调用 Agent
  → 等待用户选图
```

如果用户没有继续选图，该消息永久停在“已发送但无回复”，没有等待附件状态、取消或恢复提示。

### 6.4 图片选择

```text
相机/加号
  → 来源弹窗
  → UIImagePickerController
  → UIImage JPEG(0.85) 写 Documents/media/uploads
  → 更新本地 users.user_update_photo
  → 尝试把图片挂到最近一条固定中文文案
  → 本地随机选择 MakeupLookCatalog 素材
  → 写入占位 eye_preview 文本和固定 steps JSON
  → 插入两条固定 AI 回复
  → reload
```

这条链没有网络上传、没有 Hermes、没有真实生成任务、没有服务端附件 ID，也没有将 `isMakeupReady` 设为 `true`。

### 6.5 妆容完成跳转

```text
ChatConversationView 监听 isMakeupReady
  → onMakeupReady
  → AppSession.markMakeupGenerated()
  → makeupPreview
```

当前 `isMakeupReady` 永远不变，所以此事件链不可达。

## 7. 联调前缺口与优先级

### P0：不补就不能进行真实 Hermes 主链联调

| 编号 | 缺口 | 当前后果 | 建议责任方 |
| --- | --- | --- | --- |
| P0-01 | 页面未注入已鉴权 `RemoteAIAgentService` | 所有文字都走本地关键词 Mock | iOS |
| P0-02 | `/chat/messages` 后端 Controller/DTO 未确认 | 现有远端适配器没有可联调事实基础 | API/Hermes |
| P0-03 | 无 conversation/run 标识 | 无法实现多轮上下文、恢复与并发隔离 | 双方 |
| P0-04 | 本地用户与登录用户未绑定 | 请求可能使用 `mrs_zhang` 而非 token 用户 | iOS/API |
| P0-05 | 图片只存本地，不上传 | Hermes 看不到用户图片 | 双方 |
| P0-06 | 无消息级状态和错误 | 超时后用户无法判断是否送达，也无法安全重试 | iOS |
| P0-07 | 无幂等键 | 超时重试可能重复生成/扣费/重复消息 | 双方 |
| P0-08 | 妆容完成事件是死链 | 对话无法进入真实预览页 | iOS/Hermes |
| P0-09 | 错误被吞掉 | 401/422/429/5xx 都无 UI 与诊断 ID | iOS |
| P0-10 | 无聊天契约测试 | 字段或 envelope 漂移只能到真机发现 | 双方 |

### P1：首轮联调后应立即补齐

- 历史拉取、游标分页、本地缓存与服务端消息去重/合并。
- 发送中取消、失败重试、网络恢复、App 前后台恢复。
- 上传进度、压缩/尺寸/MIME 校验、敏感图片清理策略。
- Hermes tool/action 的结构化展示，不依赖自然语言关键词触发跳转。
- 建议词改为后端 `suggested_actions`，并保留本地默认值兜底。
- 一条消息多个附件、生成图/妆容方案卡片、可访问性文案。
- 监控：request ID、conversation ID、run ID、耗时、错误码；禁止记录 token 和图片内容。

### P2：体验增强

- SSE 流式 token、停止生成、重新生成。
- 会话列表、新建会话、会话标题、历史跨设备同步。
- 消息反馈、复制、引用、撤回/编辑策略。
- 离线只读、草稿恢复、弱网发送队列（需明确冲突策略）。

## 8. 建议前端状态机

不要继续用单个 `isLoading` 表达整个对话。建议拆成：

```text
ConversationState
  idle
  loadingHistory
  ready(conversationId)
  failed(error)

ComposerState
  idle
  preparingAttachment
  uploading(progress)
  sending(clientMessageId)
  disabled(reason)

MessageDeliveryState
  queued → sending → sent
                 ↘ failed(retryable, code, requestId)

AssistantRunState
  queued → thinking → streaming → toolRunning → completed
                 ↘ failed / cancelled

MakeupArtifactState
  none → generating(jobId) → ready(planId, preview) → failed
```

事件至少应包括：

```text
viewAppeared
createOrRestoreConversation
loadEarlier
composerChanged
sendText
pickAttachment / cancelPicker
uploadStarted / uploadProgress / uploadCompleted / uploadFailed
messageAccepted / messageFailed / retryMessage
streamDelta / assistantCompleted / assistantFailed / cancelRun
toolStarted / toolCompleted / toolFailed
makeupPlanReady / openMakeupPreview
authExpired / sessionRefreshed
appBecameActive / networkChanged
```

## 9. 当前已编码的兼容接口（只用于过渡）

### 9.1 请求

```http
POST {AURAEYE_API_BASE_URL}/chat/messages
Accept: application/json
Content-Type: application/json
Authorization: Bearer <access_token>   # 只有注入带 token 的 client 才会携带
```

```json
{
  "user_id": "mrs_zhang",
  "display_name": "Mrs.Zhang",
  "message": "我想要更清新"
}
```

### 9.2 成功响应

当前 `APIClient` 强制要求 envelope：

```json
{
  "request_id": "req_...",
  "data": {
    "message": "回复内容",
    "avatar_asset": "AvatarAI2"
  }
}
```

### 9.3 兼容接口限制

- 单轮文本；没有会话、历史、附件、幂等、工具调用和生成物。
- 请求体里的 `user_id` 可被伪造，不应作为资源归属依据。
- `avatar_asset` 是 iOS Asset 名称，属于客户端实现细节，不适合作为长期后端字段。
- 当前页面没有实际使用该适配器。

建议：若为了尽快冒烟联调临时实现 `/chat/messages`，后端内部也应落到同一个 conversation/Hermes service，标记 deprecated，不维护第二套对话逻辑。

## 10. 建议冻结的 Hermes v1 契约

### 10.1 边界原则

移动端只对接 AuraEye API，不直接了解 Hermes 的 prompt、模型名、工具协议或内部消息格式。NestJS/API 层负责：

- 从 Bearer token 取得用户身份；
- 创建/恢复 conversation；
- 组装用户档案、化妆品柜、天气/场景等上下文；
- 调 Hermes 并持久化 run、message、tool call；
- 把 Hermes 输出归一为稳定的客户端 DTO；
- 对敏感图像和日志执行权限、生命周期与脱敏策略。

### 10.2 公共规则

```http
Base URL: https://api-dev.peterhigh.xyz/v1
Accept: application/json
Authorization: Bearer <access_token>
Content-Type: application/json
Idempotency-Key: <client_message_id>   # 创建/发送必填
```

成功响应：

```json
{
  "request_id": "req_01...",
  "data": {}
}
```

失败响应优先使用 `application/problem+json`：

```json
{
  "type": "https://api-dev.peterhigh.xyz/problems/hermes-unavailable",
  "title": "Hermes unavailable",
  "status": 503,
  "detail": "对话服务暂时不可用，请稍后重试。",
  "code": "HERMES_UNAVAILABLE",
  "request_id": "req_01...",
  "retryable": true,
  "errors": []
}
```

后端同时返回 `X-Request-Id`；429/503 若可重试则返回 `Retry-After`。

### 10.3 创建或恢复会话

```http
POST /conversations
Idempotency-Key: <client-generated-id>
```

```json
{
  "client_conversation_id": "ios_conv_01...",
  "channel": "negative_one_screen",
  "scene": null
}
```

建议返回 `201`；同一用户同一幂等键重放返回同一资源：

```json
{
  "request_id": "req_01...",
  "data": {
    "id": "conv_01...",
    "status": "active",
    "title": "今日妆容",
    "created_at": "2026-08-21T07:00:00Z",
    "updated_at": "2026-08-21T07:00:00Z"
  }
}
```

### 10.4 拉取消息历史

```http
GET /conversations/{conversation_id}/messages?before=<message_id>&limit=30
```

```json
{
  "request_id": "req_01...",
  "data": {
    "items": [],
    "next_cursor": null,
    "has_more": false
  }
}
```

服务端固定按 `created_at, id` 升序返回当前页；`before` 用于拉更早消息。

### 10.5 上传聊天图片

沿用统一媒体接口，避免发送超时导致重复传图：

```http
POST /media
Content-Type: multipart/form-data
Authorization: Bearer <access_token>
Idempotency-Key: <upload-id>
```

表单：

- `file`：`image/jpeg | image/png | image/heic`
- `purpose`：固定 `chat`
- `client_attachment_id`：客户端生成 ID

```json
{
  "request_id": "req_01...",
  "data": {
    "id": "media_01...",
    "type": "image",
    "mime_type": "image/jpeg",
    "width": 1170,
    "height": 2532,
    "status": "ready",
    "created_at": "2026-08-21T07:01:00Z"
  }
}
```

需要双方另行冻结：最大文件大小、最大像素、HEIC 是否由服务端转码、原图保留时长和删除接口。

### 10.6 发送消息（首轮建议先用非流式 JSON）

```http
POST /conversations/{conversation_id}/messages
Idempotency-Key: <client_message_id>
```

```json
{
  "client_message_id": "ios_msg_01...",
  "kind": "text",
  "text": "这是我的照片，想要适合今天去公园的清透妆容",
  "attachment_ids": ["media_01..."],
  "client_context": {
    "timezone": "Asia/Shanghai",
    "locale": "zh-Hans-CN"
  }
}
```

约束：

- `kind`: `text | image | mixed`；`text` 可为空仅当存在附件。
- 用户归属只取 token，不接受客户端 `user_id` 决定归属。
- `client_message_id` 与 `Idempotency-Key` 必须相同。
- 同一用户、路由、幂等键、请求摘要相同：返回原结果；摘要不同：409 `IDEMPOTENCY_CONFLICT`。
- 首轮非流式建议等待上限不超过客户端 45 秒；预计更久的妆容生成必须转异步 artifact/job。

建议响应：

```json
{
  "request_id": "req_01...",
  "data": {
    "conversation_id": "conv_01...",
    "run": {
      "id": "run_01...",
      "status": "completed",
      "model_provider": "hermes"
    },
    "user_message": {
      "id": "msg_user_01...",
      "client_message_id": "ios_msg_01...",
      "sender": "user",
      "kind": "mixed",
      "text": "这是我的照片，想要适合今天去公园的清透妆容",
      "attachments": [{"id": "media_01...", "type": "image"}],
      "status": "sent",
      "created_at": "2026-08-21T07:02:00Z"
    },
    "assistant_message": {
      "id": "msg_ai_01...",
      "sender": "assistant",
      "kind": "text",
      "text": "收到，我会结合你的档案和场景生成清透妆容。",
      "attachments": [],
      "status": "sent",
      "created_at": "2026-08-21T07:02:02Z"
    },
    "suggested_actions": [
      {
        "id": "act_01...",
        "type": "generate_makeup",
        "title": "生成妆容",
        "payload": {"scene": "park"}
      }
    ],
    "artifacts": []
  }
}
```

`model_provider` 仅用于诊断，可不展示；客户端业务不能根据它分支。

### 10.7 Hermes 工具调用与妆容生成物

Hermes 内部 tool call 不应原样透传。API 应转换为稳定业务事件/产物：

| API 类型 | 客户端含义 | UI 行为 |
| --- | --- | --- |
| `suggested_actions[].type=generate_makeup` | 可发起生成 | 展示可点击建议，不自动跳转 |
| `artifact.type=makeup_plan` + `status=generating` | 已创建生成任务 | 展示真实进度/可取消状态 |
| `artifact.type=makeup_plan` + `status=ready` | 方案可用 | 设为 makeupReady，展示“查看妆容”并跳转 |
| `artifact.status=failed` | 生成失败 | 展示错误与按契约重试 |

建议 artifact：

```json
{
  "id": "artifact_01...",
  "type": "makeup_plan",
  "status": "ready",
  "makeup_plan_id": "look_01...",
  "preview_media_id": "media_preview_01...",
  "preview_url": "https://...",
  "expires_at": "2026-08-21T08:00:00Z"
}
```

只有收到服务端 `ready` 才触发 `onMakeupReady`；不能再用固定 3 秒动画代表完成。

### 10.8 可选 SSE 契约（P2）

首轮联调可暂不做流式。启用时建议：

```http
POST /conversations/{conversation_id}/messages/stream
Accept: text/event-stream
```

事件类型：

```text
message.accepted
run.started
message.delta
tool.started
tool.completed
artifact.updated
message.completed
run.completed
error
```

每个事件必须带 `event_id`、`request_id`、`conversation_id`、`run_id`；断线恢复使用 `Last-Event-ID`。`message.delta` 只传增量文本，`message.completed` 传最终权威消息。客户端只在 completed 后写入最终缓存。

## 11. 错误码与客户端映射

| HTTP | 建议 code | 可重试 | 客户端行为 |
| --- | --- | --- | --- |
| 400 | `INVALID_MESSAGE` | 否 | 保留草稿，字段提示 |
| 401 | `AUTH_EXPIRED` | 条件式 | 公共层刷新一次并重放一次 |
| 403 | `CONVERSATION_FORBIDDEN` | 否 | 退出当前会话，不泄露资源存在性 |
| 404 | `CONVERSATION_NOT_FOUND` | 否 | 清理失效 conversation，提示新建 |
| 409 | `IDEMPOTENCY_CONFLICT` | 否 | 不自动重试，记录 request ID |
| 413 | `ATTACHMENT_TOO_LARGE` | 否 | 重新压缩/选择 |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | 否 | 提示支持格式 |
| 422 | `IMAGE_NOT_USABLE` / `CONTENT_BLOCKED` | 否 | 不重复提交，显示可理解原因 |
| 429 | `RATE_LIMITED` | 是 | 按 Retry-After 禁用发送并倒计时 |
| 500 | `INTERNAL_ERROR` | 条件式 | 显示重试，携带 request ID |
| 503 | `HERMES_UNAVAILABLE` | 是 | 保留失败消息，允许幂等重试 |
| 504 | `HERMES_TIMEOUT` | 是 | 先按 client_message_id 查询/恢复，避免重复生成 |

## 12. 建议前端落地文件结构

不要求一次性重构全工程；最小可维护拆分如下：

```text
MakeupChat/Features/Chat/
├─ Models/
│  ├─ ConversationDTO.swift
│  ├─ ChatMessageDTO.swift
│  ├─ ChatAttachmentDTO.swift
│  ├─ AssistantRunDTO.swift
│  └─ ChatArtifactDTO.swift
├─ API/
│  ├─ ChatAPI.swift                       # 协议
│  ├─ RemoteChatAPI.swift                 # conversation/messages/media
│  └─ ChatAPIErrorMapper.swift
├─ Persistence/
│  ├─ ChatCacheRepository.swift           # SQLite 缓存/去重/分页
│  └─ ChatMigration.swift                 # 旧表升级
├─ Domain/
│  ├─ ChatCoordinator.swift               # 会话、发送、上传、run 编排
│  └─ ChatState.swift                     # 明确状态机
├─ UI/
│  ├─ ChatConversationView.swift
│  ├─ ChatViewModel.swift
│  └─ Components/
└─ Tests/
   ├─ ChatContractTests.swift
   ├─ ChatViewModelTests.swift
   ├─ ChatIdempotencyTests.swift
   └─ ChatRecoveryTests.swift
```

根节点应创建一次已鉴权服务并注入首页与路由入口；两个入口不得各自默认 `ChatViewModel()`。如果产品最终只保留首页同层入口，应删除或明确标注另一路由仅用于 Preview，避免出现两套生命周期。

## 13. 前后端沟通目录（建议按此顺序开联调会）

### 13.1 会前必须提供

| 责任方 | 交付物 |
| --- | --- |
| API 后端 | Controller/DTO/状态码、OpenAPI、测试环境 URL、健康检查结果 |
| Hermes | 输入上下文清单、输出类型、工具清单、超时/并发/安全策略 |
| iOS | 本文、当前请求样例、页面状态清单、构建版本与设备环境 |
| 测试 | 主链/弱网/重复提交/图片权限/安全用例 |
| 运维 | 环境变量、域名/TLS、日志与 trace 查询方式、限流配置 |

### 13.2 会议议程与必须结论

1. **范围**：首轮只做非流式文本，还是文本 + 图片 + 妆容 artifact。
2. **身份**：确认只认 token `sub`；本地 `mrs_zhang` 如何迁移到真实用户。
3. **会话**：何时新建、何时恢复、一个用户是否允许多个 active conversation。
4. **消息**：字段、长度、排序、幂等、超时后查询与重放规则。
5. **图片**：格式、大小、像素、上传接口、保留时长、删除与审核。
6. **Hermes 上下文**：档案、柜内产品、天气、历史由谁查询；禁止客户端上传无限历史。
7. **工具/产物**：工具白名单、参数校验、是否需要用户确认、妆容 ready 的唯一信号。
8. **错误**：冻结 HTTP/code/retryable/Retry-After 与用户文案归属。
9. **流式**：首轮是否关闭；若开启，冻结事件、断线恢复和最终消息规则。
10. **观测**：request/conversation/run/message ID 如何串联；日志脱敏字段。
11. **发布**：dev/staging/prod 地址、Feature Flag、本地 Mock 只能在哪个 Scheme 使用。
12. **验收**：双方契约测试、真机矩阵、回滚开关和签字人。

### 13.3 待双方明确回答的问题

- NestJS 当前是否已经存在 `/chat/messages` 或 `/conversations` Controller？对应 commit/OpenAPI 在哪里？
- “Hermes”具体是模型服务、Agent runtime，还是现有后端内的一个模块？调用是同步、异步任务还是流式？
- Hermes 是否支持图片原生输入；若不支持，由哪个视觉服务先产出描述/特征？
- Hermes 会调用哪些工具：查档案、查化妆品、查天气、生成妆容、渲染预览？
- 工具执行是否收费/扣积分，哪些动作必须用户二次确认？
- 生成妆容预计 P50/P95 耗时；超过 45 秒时使用什么 job/artifact 查询接口？
- 内容安全拒绝如何编码，用户图片多久删除，谁能访问原图？
- 会话历史是否跨设备；本地 SQLite 是缓存、草稿源还是仍为权威源？
- 首轮是否必须 SSE；若不必须，切换流式的 Feature Flag 名称是什么？

## 14. 联调实施顺序

### 阶段 A：契约冻结与冒烟

1. 后端提供 OpenAPI 和 curl，确认 envelope、Bearer、Problem Details。
2. 实现/确认 `POST /conversations`、历史 GET、文字 POST。
3. iOS 增加契约 DTO 测试并注入一个统一远端 Chat service。
4. 用测试账号完成两轮真实文本对话，核对 conversation/run/request ID。

### 阶段 B：图片链

1. 冻结 `/media` 限制与生命周期。
2. iOS 增加 preparing/uploading/failed/retry 状态。
3. 完成 mixed message，确认 Hermes 实际拿到附件或视觉结果。
4. 覆盖取消相册、无权限、413、415、422、上传超时和幂等重试。

### 阶段 C：妆容产物链

1. 冻结 `suggested_action` 与 `makeup_plan artifact`。
2. 后端把 Hermes 工具输出归一为 artifact/job。
3. iOS 以服务端 `artifact.status=ready` 驱动 `isMakeupReady` 和预览跳转。
4. 删除固定中文匹配、随机本地妆容、3 秒伪完成逻辑。

### 阶段 D：恢复、流式与发布

1. 历史分页、服务端/本地去重、App 重启与前后台恢复。
2. 如有必要再启用 SSE，并完成断线恢复。
3. 真机弱网、重复点击、401 刷新、429、503、超时与回滚测试。
4. 关闭 Release 本地 Mock，完成 staging 验收后再发布。

## 15. 最小验收标准

- 登录用户 ID 与 conversation 所属用户一致，客户端无法通过请求体越权。
- 连续至少两轮对话使用同一 conversation，Hermes 能引用上一轮上下文。
- 同一个 `client_message_id` 重放不会产生重复用户消息、AI 回复或扣费。
- 图片消息在后端可定位到 media ID；日志不出现 token、图片字节或本地绝对路径。
- 401 仅刷新并重放一次；429/503 按契约显示可重试；422 不自动重试。
- App 杀进程重开后能恢复服务端消息，且不重复本地消息。
- 妆容跳转只由服务端 ready artifact 驱动，失败时留在聊天页并可诊断。
- 两个聊天入口使用同一依赖来源；Release 中不默认启用 Local Agent。
- 契约测试覆盖成功 envelope、Problem Details、字段缺失、未知枚举和时间格式。
- Debug 无签名 Simulator 构建与聊天测试通过，staging 真机主链通过。

## 16. 当前代码中应优先修改的位置（进入实施阶段后）

| 文件 | 第一批修改目的 |
| --- | --- |
| `Views/HomeView.swift` | 移除页面内默认 VM，接收统一依赖 |
| `Views/NegativeOneScreen01View.swift` | 与首页入口共用同一依赖策略 |
| `ViewModels/ChatViewModel.swift` | 明确状态机、错误、重试、conversation、attachment、artifact |
| `Services/AIAgentService.swift` | 将单轮 `reply` 升级/替换为 conversation API 协议 |
| `Services/RemoteAPIService.swift` | 增加 conversation/media DTO 与调用；旧接口标 deprecated |
| `Services/ChatSessionService.swift` | 从“本地业务权威源”调整为缓存/迁移层，删除演示回复 |
| `Models/ChatMessage.swift` | 增加服务端 ID、client ID、状态、附件、run/artifact 关联 |
| `Repositories/ChatRepository.swift` | Schema 迁移、upsert、分页、去重与失败状态 |
| `Components/ChatBubbleView.swift` | 发送中/失败/重试/附件/产物 UI |
| `Views/ChatConversationView.swift` | 上传/发送/流式/产物事件绑定，移除共享伪进度状态 |

## 17. 文档维护规则

- 一旦后端提供真实 Controller/OpenAPI，把本文第 10 节的“建议”更新为“已冻结”，并记录版本号、commit 和日期。
- 每次字段或状态码变化，同时更新 `docs/20_phase_2_backend_api/13_前后端接口台账.md`。
- 已实现、已部署、已注入、已真机验收是四个不同状态，台账不得合并表述。
- `/chat/messages` 若保留兼容期，必须写明废弃日期和调用量归零条件。
- 联调记录应只保存脱敏 request/conversation/run/message ID，不保存 token、密码、图片或完整用户档案。
