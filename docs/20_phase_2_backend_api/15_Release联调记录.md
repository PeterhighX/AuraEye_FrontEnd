# AuraEye Release 联调记录

更新时间：2026-08-11  
当前总状态：进行中（代码、Release Build、Archive 与 XCTest 已完成；真机线上回归待完成）

## Release 资源

| 文件 | 源文件 SHA-256 | Archive SHA-256 |
| --- | --- | --- |
| `demo_face_portrait_001.jpg` | `c898ffe774e39d101a7fa81f62e4674d12c5a5d62cbe911546944c845f424ac3` | `c898ffe774e39d101a7fa81f62e4674d12c5a5d62cbe911546944c845f424ac3` |
| `demo_tool_brush_set_001.jpg` | `08fbbff58ad62189f3872490f2145de10f77986397cd3d1a3ece01405f72f63c` | `08fbbff58ad62189f3872490f2145de10f77986397cd3d1a3ece01405f72f63c` |
| `demo_cosmetic_eyeliner_001.jpg` | `1821450a2e4128100eef87b9d2b5c0e6b29e8e6b02ac82462cffe92a0b806b53` | `1821450a2e4128100eef87b9d2b5c0e6b29e8e6b02ac82462cffe92a0b806b53` |
| `demo_cosmetic_eyeshadow_palette_001.jpg` | `ee3911439a331c138c96cdb95c47d755d7ecfb42ef7c1692584b8bfcbacd55d0` | `ee3911439a331c138c96cdb95c47d755d7ecfb42ef7c1692584b8bfcbacd55d0` |

manifest 源文件 SHA-256：`caaf8a371d6c65e63c08a3cbd85d481c70072f206c4ac3dee792da7ef958f2ae`

## 构建与认证

| 项目 | 结果 |
| --- | --- |
| Release `EXCLUDED_SOURCE_FILE_NAMES` | 已删除 `DemoFixtures` |
| Resources Build Phase | 保留 `DemoFixtures in Resources` |
| 本地认证 Stub | Release Build/Archive 通过；可执行文件无 Stub 类名、条件或本地 token 标记 |
| Release API Base URL | Archive Info.plist 已确认为 `https://api-dev.peterhigh.xyz/v1` |
| XCTest | 31 项；29 通过、0 失败、2 跳过 |
| Archive | `/private/tmp/MakeupChat-Release.xcarchive`，无签名验收包 |

## 线上三流程

| 流程 | 最终状态 | request_id | 错误码 |
| --- | --- | --- | --- |
| 首页首次建档 | 待真机 | — | — |
| 档案详情重新分析 | 待真机 | — | — |
| 快速开始建档 | 待真机 | — | — |

禁止在本记录中写入 access token、refresh token、密码或图片原始数据。
