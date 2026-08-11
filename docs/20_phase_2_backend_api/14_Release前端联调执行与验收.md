# AuraEye Release 前端联调执行与验收

更新时间：2026-08-11

## 范围

仅修改前端 Release 联调链路。不修改后端服务、账号权限、服务端 Feature 字段、固定图片内容或视觉接口字段。

## 验收清单

| 项目 | 实现状态 | 验收状态 |
| --- | --- | --- |
| Release 包含 DemoFixtures | 已删除 Release 的资源排除配置，保留 Resources Build Phase | Release Build 与 Archive 均包含 manifest 和四图，通过 |
| canonical 人脸 SHA | 源文件为 `c898ffe774e39d101a7fa81f62e4674d12c5a5d62cbe911546944c845f424ac3` | Archive 内 SHA 一致，通过 |
| fixed_demo 隐藏相机 | 首页、建档、档案详情、快速开始、化妆品柜已统一传入 `showsCamera = false` | 待安装包人工验收 |
| authorized_library 保持原逻辑 | `showsCamera = true`，仍显示“拍照 + 相册” | 待安装包人工验收 |
| 重新分析复用原始 Data | 已通过 `LocalMediaStore.loadData` 与文件扩展名恢复 MIME | 同字节请求单元测试通过 |
| 旧档案保护 | fixed_demo 非 canonical 原图不上传，提示重新选择演示人脸图 | 待安装包人工验收 |
| Release 禁止本地认证 Stub | 已增加构建期检查 | Release Build/Archive 通过；二进制无 Stub 标记 |
| 真机首次建档 | 未执行 | 待真机与线上 API |
| 真机重新分析 | 未执行 | 待真机与线上 API |
| 真机快速开始 | 未执行 | 待真机与线上 API |

## 真机执行顺序

1. 干净安装或明确重置本地测试数据。
2. 使用 `aurayetest` 登录，确认固定演示相册恰好四张图片。
3. 首页用户档案选择固定“面部照片”，确认 Job 轮询至 `succeeded`。
4. 档案详情点击“重新分析”，不重新选择图片，确认仍命中相同 demo 缓存。
5. 重装或重置后进入快速开始，选择同一人脸图，确认建档成功。
6. 失败时只记录阶段、HTTP 状态、后端错误码和脱敏 request_id。

## 自动化结果

- Release Simulator Build：通过。
- 无签名真机 Release Archive：通过，路径 `/private/tmp/MakeupChat-Release.xcarchive`。
- 最终 App Info.plist：`AURAEYE_API_BASE_URL=https://api-dev.peterhigh.xyz/v1`。
- 完整 XCTest：31 项，29 通过、0 失败、2 个环境依赖测试跳过。

全部代码、Archive 与真机项目通过后，才能把本轮状态标记为“已完成”；当前仅真机线上三流程未执行。
