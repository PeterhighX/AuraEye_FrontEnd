# AuraEye Chat BFF 与 Hermes SSE 同步改造执行文档

更新日期：2026-09-22  
适用范围：`PeterhighX/AuraEye/apps/auraeye-api`、Hermes `v2026.7.7.2`、AuraEye iOS 负一屏  
状态：`待后端执行；前端 ExyteChat + SSE 首版已接入并通过编译验证`

## 1. 执行结论

本增量将现有 `POST /v1/chat/messages` 从“等待 Hermes 完整回复后返回 201 JSON”改为
“建立成功后持续返回 `text/event-stream`”。不保留旧的非流式 Chat DTO、兼容路由或自动
降级逻辑。

Hermes 已提供可直接使用的 Responses SSE：

- `POST /v1/responses`，请求体设置 `stream: true`；
- 文本增量：`response.output_text.delta`；
- 工具状态：`response.output_item.added`、`response.output_item.done`；
- 成功终态：`response.completed`；
- 失败终态：`response.failed`；
- 空闲期间输出 SSE keepalive；
- 客户端断开时中断当前 Agent 任务。

AuraEye API 必须作为唯一公网 BFF。iOS 不得直接访问 Hermes，也不得接触
`HERMES_API_KEY`。BFF 不原样公开 Hermes 事件，而是转换为稳定的 AuraEye Chat 事件。

## 2. 已核验事实

当前 AuraEye 后端：

1. `ChatController` 仅有同步 `POST /chat/messages`；
2. `HermesClient.reply()` 调用 `/v1/responses`，但没有设置 `stream: true`；
3. 当前实现通过 `await response.json()` 等待完整结果；
4. 当前成功契约为 HTTP 201 JSON，并包含客户端 UI 字段 `avatar_asset`；
5. Prisma 尚无 Chat Run、Chat Message 或 Chat Event 表；
6. JWT 用户、tenant/user/conversation 隔离和 Hermes Session Key 已实现；
7. Hermes 固定版本为 `v2026.7.7.2`，对应源码 commit
   `3b2ef789dfcf92f5b7b18c08c59d25948e50857f`。

Hermes 固定版本存在一项必须由 BFF 补齐的限制：`/v1/responses` 的流式分支在
`Idempotency-Key` 缓存逻辑之前返回，因此流式请求不能依赖 Hermes 自身完成幂等保护。

Hermes `/v1/runs/{run_id}/events` 暂不作为本阶段上游协议。该版本使用单个进程内队列，
没有事件 ID 重放或 `Last-Event-ID` 恢复，订阅断开后还会移除队列；它适合 Hermes 控制面，
不适合作为 AuraEye 移动端的直接公开协议。

## 3. 目标链路

```text
iOS ExyteChat
  -> Bearer POST /v1/chat/messages
  -> AuraEye NestJS Chat BFF
  -> 校验/占用 request_id
  -> Docker 私网 POST Hermes /v1/responses { stream: true }
  -> 解析 Hermes Responses SSE
  -> 转换为 AuraEye Chat SSE
  -> iOS 增量更新同一条助手消息
```

## 4. 公共请求契约

```http
POST /v1/chat/messages
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: text/event-stream
```

```json
{
  "request_id": "req_chat_01J...",
  "conversation_id": "conversation_01J...",
  "message": "请推荐适合通勤的清新妆容"
}
```

约束继续沿用现有冻结规则：

- `request_id`：8–128 字符，仅允许 `[A-Za-z0-9._:-]`；
- `conversation_id`：8–128 字符，规则同上；
- `message`：Trim 后 1–4000 字符；
- 用户与租户只取 JWT；不得接收 `user_id`、`tenant_id`、`display_name`；
- 首次发送与重试必须复用同一个 `request_id`。

## 5. AuraEye SSE 公共事件

每个正式事件必须包含：

```json
{
  "type": "assistant.delta",
  "sequence": 3,
  "request_id": "req_chat_01J...",
  "conversation_id": "conversation_01J...",
  "message_id": "msg_01J...",
  "created_at": "2026-09-22T10:00:00.000Z"
}
```

SSE frame：

```text
id: 3
event: assistant.delta
data: {"type":"assistant.delta",...}

```

首版事件集合：

| 事件 | 必需数据 | 客户端行为 |
| --- | --- | --- |
| `message.accepted` | `request_id, conversation_id, message_id` | 确认服务端已接受请求 |
| `assistant.started` | `message_id` | 建立或确认助手占位消息 |
| `assistant.delta` | `delta` | 追加到同一条助手消息 |
| `tool.started` | `tool_call_id, name` | 显示脱敏的工作状态 |
| `tool.completed` | `tool_call_id, name, status` | 更新工具状态，不展示原始工具输出 |
| `message.completed` | `message, hermes_response_id, usage` | 以最终全文校正增量文本并持久化 |
| `error` | `code, detail, retryable, server_request_id` | 标记本轮失败并关闭流 |

keepalive 使用标准 SSE comment：

```text
: keepalive

```

客户端必须忽略以 `:` 开头的 comment。

## 6. 错误边界

### 6.1 建立 SSE 之前

以下错误继续使用 `application/problem+json`：

- 400：DTO 校验失败；
- 401：JWT 无效；
- 409：同一 `request_id` 对应不同请求正文；
- 429：并发或频率限制；
- 503：Hermes 未配置或无法建立连接。

### 6.2 建立 SSE 之后

HTTP headers 已发送后不得再尝试返回 Problem Details。所有错误转换为终态 `error` 事件，
随后正常结束 SSE：

| 来源 | AuraEye code | retryable |
| --- | --- | --- |
| Hermes `response.failed` | `HERMES_RUN_FAILED` | 依据错误类型，默认 `true` |
| 上游格式错误 | `HERMES_INVALID_STREAM` | `true` |
| 上游连接中断 | `HERMES_STREAM_INTERRUPTED` | `true` |
| BFF 超时 | `HERMES_TIMEOUT` | `true` |
| 客户端主动取消 | 不发送用户可见错误 | 不适用 |

日志与 SSE 均不得包含 Token、Hermes key、Provider key、完整工具参数、原始图片或服务器
绝对路径。

## 7. BFF 幂等与运行状态

不得依赖 Hermes 流式路径的 `Idempotency-Key`。新增最小 `ChatRun` 持久化模型：

```text
id
tenant_id
user_id
conversation_id
client_request_id
request_digest
status              running / completed / failed / cancelled
message_id
hermes_response_id
assistant_text
error
created_at
updated_at
completed_at
```

唯一约束：

```text
(tenant_id, user_id, client_request_id)
```

处理规则：

1. 新 ID：原子创建 `running`，之后才允许调用 Hermes；
2. 相同 ID、不同 digest：返回 409 `CHAT_IDEMPOTENCY_CONFLICT`；
3. 相同 ID、状态 `completed`：通过 SSE 重放 accepted/started/completed，不再次调用 Hermes；
4. 相同 ID、状态 `running`：返回 409 `CHAT_REQUEST_IN_PROGRESS`，不启动第二个 Agent；
5. 相同 ID、状态 `failed`：只有 `retryable=true` 时才允许显式重试；实现时通过带条件的
   原子更新重新占用，禁止并发重复执行；
6. API 进程异常退出遗留的 `running` 必须由超时规则转为 `failed`，不得永久占用。

首版不保存每个 token 事件。只保存运行状态和最终助手全文；跨连接逐事件续传属于后续
增量。如产品要求真正的断点续传，再增加带 sequence 的 ChatEvent journal。

## 8. Hermes 上游映射

上游请求：

```json
{
  "model": "auraeye",
  "input": "用户正文",
  "conversation": "auraeye:<tenant>:<user>:<conversation>",
  "store": true,
  "stream": true
}
```

Headers：

```text
Authorization: Bearer <server-only-key>
Idempotency-Key: <request_id>
X-Hermes-Session-Key: auraeye:<tenant>:<user>
Accept: text/event-stream
```

虽然仍透传 `Idempotency-Key`，但它不能替代第 7 节的 BFF 幂等。

映射规则：

| Hermes | AuraEye |
| --- | --- |
| `response.created` | `assistant.started`，保存 response id |
| `response.output_text.delta` | `assistant.delta` |
| function call `response.output_item.added` | `tool.started` |
| function call/output `response.output_item.done` | `tool.completed` |
| `response.completed` | `message.completed` |
| `response.failed` | `error` |

工具参数和输出默认不向客户端转发，只提供允许展示的工具名、调用 ID 和状态。

## 9. NestJS 修改清单

### B1：契约与 DTO

- 保留现有三字段请求 DTO；
- 删除 `ChatMessageData.avatar_asset` 及旧完成响应 DTO；
- 新增 SSE event discriminated union；
- OpenAPI 将 201 JSON 改为 200 `text/event-stream`；
- 明确流前 Problem Details 与流内 `error` 的区别。

### B2：Hermes SSE Client

- 将 `reply()` 替换为返回 `AsyncIterable<HermesStreamEvent>` 的 `streamReply()`；
- 使用 fetch body reader 增量解析 SSE；
- 正确处理跨 chunk 的行、UTF-8 字符和多行 `data:`；
- 忽略 comment/keepalive；
- 校验事件类型和必要字段；
- 使用调用方 AbortSignal；
- 限制单事件和累计文本大小。

### B3：ChatRun 幂等

- 新增 Prisma model 与 migration；
- 原子 reserve request；
- 记录 Hermes response ID、最终文本、终态和脱敏错误；
- 增加遗留 running 超时处理；
- 不改变 VisionJob、Worker 或 Demo fixture schema/行为。

### B4：Controller 流式输出

- 设置 `Content-Type: text/event-stream; charset=utf-8`；
- 设置 `Cache-Control: no-cache, no-transform`；
- 设置 `X-Accel-Buffering: no`；
- flush headers 后先发送 `message.accepted`；
- 按 sequence 写出事件；
- 在客户端关闭连接时 abort Hermes；
- 确保任何路径只发送一个终态。

### B5：代理与部署

- Caddy 对 Chat SSE 禁止响应缓冲和压缩聚合；
- 上游 read timeout 必须大于 Hermes 单轮最大允许时间；
- API 容器继续通过私网访问 `hermes:8642`；
- 不公开 Hermes 8642 端口；
- 发布只替换 AuraEye API，并保持 Worker 与视觉配置不变。

## 10. 自动化测试

至少覆盖：

1. DTO 仍只接受三字段；
2. 未登录返回 401，且不会建立 Hermes 请求；
3. 用户正文立即产生 `message.accepted`；
4. 多个 Hermes delta 顺序映射且 sequence 单调递增；
5. UTF-8 中文跨网络 chunk 不损坏；
6. keepalive/comment 被正确处理；
7. tool started/completed 不泄露参数或输出；
8. completed 最终全文与累计 delta 一致；
9. `response.failed` 转换为唯一终态 `error`；
10. 上游断线、超时和非法事件转换正确；
11. 客户端取消会 abort Hermes；
12. 相同 request/body 不重复执行；
13. 相同 request/不同 body 返回 409；
14. running 重复请求不会启动第二个 Agent；
15. completed 请求以 SSE 重放最终结果；
16. 两个用户使用相同 request ID 时互不冲突；
17. 日志不包含密钥和敏感工具内容；
18. 视觉 API 与 Worker 回归测试保持通过。

## 11. 公网验收

1. 使用测试账号获取 JWT；
2. `curl -N` 调用 `/v1/chat/messages`；
3. 确认首个业务事件先于最终回复到达；
4. 确认收到多个 `assistant.delta`；
5. 确认以 `message.completed` 结束；
6. 同一 conversation 发送第二轮并验证上下文；
7. 使用相同 request ID 重放，不产生第二个 Hermes 执行；
8. 使用相同 request ID 和不同正文验证 409；
9. 中途断开连接，确认 Hermes 停止且 ChatRun 转为可诊断终态；
10. 停止 Hermes，确认 Chat 失败但视觉 API/Worker 正常。

保留的脱敏证据：客户端 request ID、服务端 request ID、conversation ID、message ID、
Hermes response ID、首事件耗时、首 token 耗时、总耗时和最终状态。

## 12. 完成定义

- [ ] OpenAPI、Controller、DTO、Service 与本文事件名称一致；
- [ ] BFF 使用 Hermes `/v1/responses stream:true`；
- [ ] 用户消息不再等待完整模型回复才得到服务端确认；
- [ ] iOS 能逐段接收助手文本；
- [ ] 流前和流内错误边界明确；
- [ ] BFF 自有幂等阻止重复 Agent 执行；
- [ ] 工具事件经过脱敏；
- [ ] 客户端断开会终止无消费者的 Hermes 请求；
- [ ] JWT、用户和 conversation 隔离保持有效；
- [ ] 后端 Jest、Build、migration 和公网两轮 E2E 通过；
- [ ] Hermes 故障不影响视觉 API/Worker；
- [ ] 总体指导、阶段计划、接口台账和联调记录同步更新。

## 13. 后续增量

以下内容不进入首个 SSE 闭环：

- ChatEvent 数据库日志和 `Last-Event-ID` 断点续传；
- Hermes Runs API 对外代理；
- 后台继续生成、跨设备订阅；
- 停止生成按钮、人工审批 UI；
- 图片/文件消息和妆容 artifact；
- 服务端历史分页与多会话管理。

只有在首个 SSE 文本闭环稳定后，才按实际产品需求逐项增加。
