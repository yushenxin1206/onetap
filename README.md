# 轻启 OneTap

把常用 App 里的具体动作（扫一扫、付款码、乘车码……）变成一键直达的快捷，放到首页、桌面小组件、锁屏和控制中心。

不是再做一个 App 启动器，而是把「打开微信 → 点 + → 点扫一扫」压缩成一次点击。

## 能做什么

- **能力目录**：内置微信、支付宝、QQ 音乐三个 App 及其动作，每个动作对应一个可用的 URL Scheme；也可以自己添加 App、动作和图标。
- **动作池**：在「＋」里浏览 App 和动作，点一下即加入快捷列表。
- **快捷层**：所有快捷集中管理，支持拖动排序、重命名、删除（可撤销）、设为首页主快捷；同一动作可以出现多次。
- **首页**：顶部一张 Hero 卡显示主快捷，下面是快捷宫格，点哪里跑哪里。
- **桌面小组件**：
  - 小号：整卡展示主快捷
  - 中号：2 列 × 3 行，共 6 格
  - 大号：2 列 × 6 行，共 12 格
  - 第一个空位是「添加」入口，超出格数的快捷不显示
- **锁屏组件**：两个独立组件，都可选圆形 / 方形 / 一行文字三种形态
  - 「轻启」：点一下打开 App
  - 「轻启 · 主快捷」：显示并执行首页主快捷
- **控制中心控件**（iOS 18+）：把主快捷放进控制中心。
- **快捷指令 App**：提供「打开轻启」「运行一条快捷」两个动作，后者可从已有快捷里点选。
- **复制链接**：在快捷行菜单里复制 `onetap://run/<uuid>`，可粘到任意支持 URL 的地方。
- **执行反馈**：唤起目标 App 后 1.5 秒内没有离开前台，会明确提示「没有反应」，不会假装成功。

## 运行

要求：Xcode 26、iOS 17.0+（控制中心控件需要 iOS 18）。

```bash
cd app
open OneTap.xcodeproj
```

- 选中 `OneTap` scheme，选择模拟器或已连接设备，`Run`。
- 真机运行需在 target 的 Signing & Capabilities 里选择自己的 Team；Bundle ID 为 `app.onetap.launcher`，并启用 App Group `group.app.onetap.launcher`（App 与小组件两个 target 都要）。
- 命令行构建：

```bash
xcodebuild -project OneTap.xcodeproj -scheme OneTap \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath build build
```

小组件需要在系统里手动添加：长按桌面 → 编辑 → 添加小组件 → 搜索「轻启」；锁屏同理。装完后系统索引可能需要一点时间才会出现快捷指令动作。

## URL 协议

| URL | 行为 |
| --- | --- |
| `onetap://` | 打开 App 首页 |
| `onetap://run/<uuid>` | 运行指定快捷（小组件、控制中心、App Intents 均走这条） |
| `onetap://run?id=<uuid>` | 同上，兼容写法 |
| `onetap://run?app=<appID>&action=<actionID>` | 直接运行某个能力，不需要先建快捷 |

## 数据与迁移

App 和小组件通过 App Group `group.app.onetap.launcher` 共享数据：

| Key | 内容 |
| --- | --- |
| `onetap.catalog.v1` | 能力目录（App、动作、图标、配色） |
| `onetap.shortcuts.v1` | 快捷列表 |
| `onetap.widget.snapshot.v1` | 小组件快照（标题、App 名、图标、颜色） |
| `onetap.runlog.v1` | 最近运行记录，用于首页统计 |
| `onetap.seed.version` | 内置清单铺底版本 |

- 首次启动从 `Resources/capabilities.json` 铺底。
- 内置清单版本升级时，会按 `seedVersion` 重建目录、快捷与运行记录；这是唯一会覆盖本地数据的路径。
- 文案类修订（例如内置 App 的副标题）走单独的轻量迁移，不重建快捷。
- 小组件只读快照，不解析目录、不包含执行逻辑。

## 目录结构

```
app/
  OneTap/            主 App
    Features/        首页、快捷层、添加流程、编辑器
    Models/          目录、快捷、运行记录与协调器
    Services/        执行器、小组件桥接、轻提示
    Intents/         App Intents 与动作库注册
    Resources/       capabilities.json、图标清单
  OneTapWidgets/     主屏 / 锁屏 / 控制中心组件
  Shared/            两端共享的数据模型、主题与 App Group 访问
```

## 行为说明

- 锁屏组件在锁定状态下点击会要求先解锁，这是系统行为。
- 快捷名是加入时的副本：首页、宫格、小组件显示的是快捷自己的名字；在动作编辑器里改名不会追溯已有快捷，需要的话在快捷层重命名。
- 内置 App 未填写副标题时，列表里显示「N 个入口」，没有动作则显示「还没有入口」。
