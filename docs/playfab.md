# PlayFab 接入

Godot 通过 HTTPS 调用 PlayFab Client REST API，恢复原作的昵称、收入提交和前 100 名榜单。启动菜单的 **RANKING** 打开榜单；结算页的 **排行榜 / 提交成绩** 打开带本局收入的榜单界面。玩家输入昵称并连接后，可以刷新或主动提交成绩；打开界面不会自动上传。

## 后端与兼容范围

`data/playfab.cfg` 沿用 Unity 项目的公开配置：

```ini
[playfab]
title_id="CDD5F"
statistic_name="Test"
```

Title ID 是公开项目标识，不是管理员密钥。客户端使用它调用原项目开放的接口，不需要后台管理权限。历史榜单仍属于原 PlayFab 项目；Title ID 无法用于复制账号、迁出数据或修改服务器设置。原项目是否继续开放服务由其管理者决定。

原版把输入的昵称直接当作 `CustomId`，因此同名会进入同一个账号。本迁移版使用加密随机生成的本机 ID 登录，昵称仅作显示名；修改昵称不会切换账号。新玩家会出现在同一榜单，但不会接管原版的同名账号或继承其分数。

本机 ID 与昵称保存在 Godot 用户数据目录的 `playfab_profile.cfg`，不同 Title 独立存放。登录票据只保存在内存中。清除用户数据或换设备会产生新身份；当前未实现跨设备账号绑定或找回。

## API 与服务器设置

实现使用四个接口：

| 接口 | 用途 |
| --- | --- |
| `LoginWithCustomID` | 以本机 ID 登录，首次连接创建玩家 |
| `UpdateUserTitleDisplayName` | 设置 3～25 字符的昵称 |
| `GetLeaderboard` | 读取 `Test` 的前 100 名 |
| `UpdatePlayerStatistics` | 上传最终资金，字段沿用原版 |

成绩在同一次运行中成功提交后不会再次发送；失败时可主动重试。服务器决定统计值的聚合方式，本仓库无法判断原后台使用最大值、最新值还是其他规则。当前仍是原作的客户端报分模式，未增加服务端成绩校验。

如需独立管理后台，创建自己的 PlayFab Title 后修改配置，并在该项目启用所需的客户端登录、玩家统计更新和榜单读取策略。若客户端创建玩家或更新统计被后台策略禁止，应由该后台的管理者设置对应权限或服务端流程。不要将 Developer Secret Key 放入客户端或仓库。

`export_presets.cfg` 显式包含 `data/playfab.cfg`，保证发布版能读取配置。

## 本机代理

Godot 的 HTTPRequest 不自动采用 Windows 系统代理。需要代理的开发环境可创建以下文件，填写自己的 HTTP CONNECT 代理地址：

```ini
# .local/playfab_network.cfg
[network]
https_proxy_host="127.0.0.1"
https_proxy_port=17890
```

示例端口应替换成自己的代理端口。`.local/` 已被 Git 与 Godot 资源扫描忽略，该设置只用于编辑器运行。发布版读取用户数据目录的 `playfab_network.cfg`，键名相同；没有配置时直接连接。客户端保持 HTTPS 证书验证。网络请求有超时和响应体限制，界面显示简短错误，不输出登录票据或完整服务端诊断。

## 验证范围

`tests/playfab_regression_test.gd` 使用模拟服务验证接口参数、身份持久化、改名、去重、断网、过期连接、榜单解析和真实界面信号；完整验证脚本包含该测试，不访问 PlayFab。

2026-10-06 的真实服务验证：Godot 在配置本机代理后成功使用独立匿名测试身份登录 `CDD5F`，并读取 `Test` 的 61 条榜单记录。验证没有设置测试昵称或提交成绩。成绩更新、昵称更新使用模拟服务测试；真实后台的相关权限仍需在实际使用时确认。

官方接口说明：[登录](https://learn.microsoft.com/en-us/rest/api/playfab/client/authentication/login-with-custom-id?view=playfab-rest)、[显示名](https://learn.microsoft.com/en-us/rest/api/playfab/client/account-management/update-user-title-display-name?view=playfab-rest)、[榜单](https://learn.microsoft.com/en-us/rest/api/playfab/client/player-data-management/get-leaderboard?view=playfab-rest)、[统计更新](https://learn.microsoft.com/en-us/rest/api/playfab/client/player-data-management/update-player-statistics?view=playfab-rest)。
