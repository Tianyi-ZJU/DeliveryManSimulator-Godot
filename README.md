# Delivery Man Simulator: Godot port

这是 Unity `SampleScene` 的最小可玩迁移，使用 Godot 4.7.2 standard / GDScript / Compatibility renderer。仓库根目录就是 Godot 项目，原 Unity 工程没有包含在此仓库中。

当前运行基线包括：

- 保存正式 `SampleScene` 的 58 个路口、93 条道路原始数据及背景、摄像机、出生点和标识素材；运行时使用 30 个固定道路地点（含 10 家餐厅）；
- 订单生成、11 色订单占用、1--5 级订单、接单窗口、指定单和高峰刷新；
- 点击餐厅或客户接单、容量、任务卡、点击置顶与拖动排序，强制先取餐后送达；
- 沿背景道路掩码寻路并简化为直线段，订单地点使用固定坐标表；Shift 加速、Ctrl 减速、天气速度和价格影响；
- 截止时间、迟到扣款、严重超时取消、餐厅等待与空格催餐、随机小费 / 处罚；
- 四类日末升级、每天最多两次购买、五天结束统计和 Unity 原版评级公式；
- gdmcp 运行时输入、截图、场景树和实际点击 / 拖动回归验证。

运行：在 Godot 4.7.2 standard 中打开本目录，按 F6 或 F5。

`data/map.json` 保留原始 Unity 路网，`data/visual_road_mask.json` 和 `data/visual_waypoints.json` 分别用于运行时寻路和固定订单地点。Godot 的 `.uid` 资源标识文件会提交；编辑器缓存、gdmcp 本地 CLI 和导出文件由 `.gitignore` 排除。

## 回归检查

从项目目录执行：

```powershell
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/regression_test.gd
```

最后一次结果：Godot 规则 / 路径 / 跨天回归 **1031 项通过**，其中包含 870 组独立 Unity 最短路径夹具；30 个运行时地点均通过道路归属检查。

## 尚未迁移

启动教程、原版音效 / BGM、PlayFab 登录与排行榜、完整 Settlement UI、独立 EndScene 的美术布局和存档尚未纳入这一最小迁移。当前已经迁移了结束统计与评级逻辑，后续应把这些外部依赖逐项接入并继续使用固定输入回归。
