# Delivery Man Simulator: Godot port

这是 [Delivery Man Simulator](https://github.com/Ameftn14/DeliveryManSimulator) 的 Godot 迁移版本，使用 Godot 4.7.2、GDScript 和 Compatibility 渲染器。项目保留了原作的地图、订单流程和主要玩法，并以原版道路与标识为基础继续开发。

原作试玩：[Unity Play](https://play.unity.com/en/games/58d8f6b6-778d-412f-b904-34089074b91c/delivery-man-simulator)

## 当前版本

**v1.0.0** · Godot 迁移版

版本记录见 [CHANGELOG.md](CHANGELOG.md)，版本号来源见 [VERSION](VERSION)。

## 已支持

- 黄昏山脉启动菜单、开始 / 退出和菜单音乐
- 原版地图、道路地点和订单标识
- 1～5 级订单、指定单、热门单和接单时限
- 取餐、送达、任务排序、背包容量和订单处罚
- 天气变化与动态效果、加速、餐厅等待、催餐和五天流程
- 日末结算、升级和最终评级
- 原版 BGM、操作音效、静音和慢速音乐效果
- 首次遇到天气或特殊订单时的简短提示
- PlayFab 昵称、在线排行榜和结算后成绩提交

## 下载与运行

Windows 64 位玩家可从 [Releases](https://github.com/Tianyi-ZJU/DeliveryManSimulator-Godot/releases/latest) 下载游戏压缩包，解压后运行 `DeliveryManSimulator.exe`。请将 `.exe` 与 `.pck` 保留在同一目录，无需安装 Godot。

如需从源码运行：

需要安装 [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/)。

```powershell
git clone https://github.com/Tianyi-ZJU/DeliveryManSimulator-Godot.git
cd DeliveryManSimulator-Godot
```

用 Godot 导入项目并按 **F5** 从启动菜单运行。也可以从项目目录执行：

```powershell
godot --path . --editor
```

## 操作

| 操作 | 功能 |
| --- | --- |
| 鼠标左键 | 接单、取餐、送达和操作界面 |
| 拖动任务卡 | 调整派送顺序 |
| Shift | 加速 |
| Ctrl | 慢速 |
| Space | 催餐或进入下一天 |
| M | 静音 / 恢复声音 |
| Q | 提前结束当前工作日 |

## 项目状态

这是一个持续迁移项目。启动教程、完整结算美术、独立结束场景和存档功能尚未迁移。

排行榜沿用原作的 PlayFab 项目，使用昵称和本机独立身份连接；联网失败不影响单机游玩。该后端由原项目管理，运行配置见 [PlayFab 接入说明](docs/playfab.md)。

原项目及其素材的权利归属保持不变；本仓库目前没有为原作素材提供新的再授权许可。使用、修改或再分发相关素材前，请先确认原作者和各素材的许可范围。

开发者可运行 `tools/verify_godot.ps1` 执行完整 Godot 回归检查。代码结构见 [维护文档](docs/architecture.md)，详细变更记录见 [CHANGELOG.md](CHANGELOG.md)。
