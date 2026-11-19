# iOS 跨 App 触发能力 · 调研笔记

## 硬边界
- iOS 沙箱：没有 Android AccessibilityService / 广播 Intent 那套跨应用控制能力。
- 第三方 App 不能读取别的 App 的界面、不能模拟点击、不能读别的 App 的播放状态（MediaRemote 是私有 API）。
- 能做的只有三类：① 用公开入口「打开」另一个 App 或页面；② 通过系统 Shortcuts 执行用户自己创建的动作；③ 把入口铺到系统表面（桌面/锁屏/控制中心/Siri）。

## 路径清单
| 路径 | 能做什么 | 限制 | 稳定性 | 结论 |
|---|---|---|---|---|
| 自定义 URL Scheme（qqmusic://） | 唤起 App，部分路由可直达页面 | 未公开文档、随版本变化、需 LSApplicationQueriesSchemes 白名单 | 低 | P0 兜底 |
| Universal Link（y.qq.com/...） | 已安装则进 App，未安装降级网页；可指向歌单页 | 依赖对方 AASA 配置，页面路由可能变 | 中高 | 首选 |
| App Intents | 把「轻启自己的动作」暴露给快捷指令/Siri/聚焦 | 不能给别人 App 注入动作 | 高 | 反向入口 |
| Shortcuts（shortcuts://run-shortcut） | 调起用户自建的快捷指令 | 用户需先建一次；部分情况会切到快捷指令 App；无法模拟点击 | 中 | 桥接 |
| Siri | 语音触发，路由到 App Intents / 快捷指令 | 不能代替用户操作别的 App | 高 | 入口增强 |
| 剪贴板 | 复制链接/文本，用户自己粘贴 | 不是自动化，会有粘贴提示 | 高 | 降级方案 |
| 分享扩展 | 接收别的 App 分享进来的内容 | 方向相反，不能推内容进别人 App | 高 | 不适用 |
| 小组件 / 控制中心(iOS18) / 操作按钮 / 锁屏 | 提供入口，本质仍是 openURL 或 AppIntent | 扩展内不能直接拉起别的 App，需回到宿主或 Intent | 高 | 分发入口 |
| 私有 API（MediaRemote、LSApplicationWorkspace、UI 自动化） | 真·遥控 | 审核必拒 / 企业签才能用 | — | 不做 |
| 开放平台 SDK（QQ 音乐等） | 在自家 App 内播放曲库内容 | 需商务合作、授权、分成 | 高 | 终局方案 |

## 「播放 QQ 音乐今日推荐」落地阶梯
- L0 真·一键自动播放：第三方 App 不可能。iOS 没有跨 App 的"执行动作"通道。
- L1 Universal Link / Scheme 直达「每日推荐」页：1 次点击 + 1 次点播放。体验上限。
- L2 快捷指令桥：用户自建「打开每日推荐」；轻启调用 shortcuts:// 执行。若目标 App 提供快捷指令动作，可能更接近一步。
- L3 降级：复制歌单链接 + 提示 + 打开 App 首页。
- L4 替代终局：轻启内嵌播放器（开放平台授权），真正一键播放，但播放发生在轻启内。

## 工程要点
- Info.plist LSApplicationQueriesSchemes 声明才能 canOpenURL；实际 open 不强制但需要 scheme 合法。
- Universal Link 用 universalLinksOnly: true 判断安装，失败再退 scheme。
- 结果无法真验证：只能监听 scenePhase 回前台 + 超时（1.5s）推断"已唤起"，文案必须说"已打开"。
- 能力清单（App → 动作 → URL 模板 → 置信度）走远程 JSON，可热更新，避免每次发版。
- 审核：2.5.1 只用公开 API；不做远程下发可执行代码；第三方商标/图标需自绘或授权。
