# 原版音频素材

这些 MP3 直接复制自本地原 Unity 项目，没有重新编码。原 Unity 工程未包含在 Godot 仓库中；此处记录对应关系，不改变素材原有的权利归属。

| Godot 文件 | 原 Unity 文件 | 播放时机 |
| --- | --- | --- |
| `music/I.mp3` ～ `music/V.mp3` | `Assets/Resources/BGM/I.mp3` ～ `V.mp3` | 第 1 ～ 5 天，按原 `BgmManager.cs` 顺序循环 |
| `sfx/accept.mp3` | `Assets/Music/ding.mp3` | 成功接单（原 `AcceptVoice`） |
| `sfx/delivery.mp3` | `Assets/Music/coin.mp3` | 送达（原 `FinishVoice`） |
| `sfx/late.mp3` | `Assets/Music/Villager_idle2.ogg.mp3` | 超时及催餐（原 `LateVoice`） |
| `sfx/boost.mp3` | `Assets/Music/Firework_launch1.ogg.mp3` | 开始加速（原 `SpeedUpVoice`） |
| `sfx/button.mp3` | `Assets/Music/button.mp3` | 菜单和成功购买升级 |
| `menu/menu.mp3` | `Assets/Resources/BGM/BGM1.mp3` | 原 `Start.unity` 启动界面的循环音乐 |
| `menu/button.mp3` | `Assets/Music/button.mp3` | 开始 / 退出按钮 |

`scripts/game_audio.gd` 管理循环音乐和可重叠的一次性音效。取餐抵达餐厅时不播放额外音效，与原 Unity 流程一致；只有送达顾客时播放 `FinishVoice` 对应的金币音效。每次跨天停止旧播放再换曲，Ctrl 减速时 BGM 音高逐渐降至 0.5，松开后恢复。日末升级和最终结算停止游戏 BGM。

启动菜单由 `scripts/main_menu.gd` 单独管理音频，进入游戏时停止菜单音乐。
