# Aiursoft 所有基础设施使用 Authentik 来进行统一身份验证

## OpenWeb Chat

* 基于 OpenId Connect 协议。
* Client ID 和 Client Secret 需要通过环境变量传递给 OpenWeb Chat 服务。
* 基于环境变量继承权限信息。可以将具有特定 `group` 的用户添加到 OpenWeb Chat 的管理员组中。
* 在合并用户时自动根据 Email 进行匹配。
* 注销时只会注销 OpenWeb Chat 的会话，不会影响 Authentik 的会话。

注意，需要额外配置环境变量 `OAUTH_ADMIN_ROLES=openweb-admins` 来让具有特定 `group` 的用户成为 OpenWeb Chat 的管理员。

注意：需要额外配置环境变量 `ENABLE_OAUTH_ROLE_MANAGEMENT=True` 来启用角色管理功能。

注意：需要额外配置环境变量 `ENABLE_SIGNUP=False` 来让 OpenWeb Chat 禁用注册功能。

## Jellyfin

* 基于 OpenId Connect 协议。
* Client ID 和 Client Secret 需要通过应用内的插件配置传给 Jellyfin 服务。
* 基于插件的配置继承权限信息。可以将具有特定 `group` 的用户添加到 Jellyfin 的管理员组中。
* 在合并用户时自动根据用户名进行匹配。
* 注销时只会注销 Jellyfin 的会话，不会影响 Authentik 的会话。

注意，需要额外配置插件配置 `Admin Roles:jellyfin-admins` 来让具有特定 `group` 的用户成为 Jellyfin 的管理员。

注意，需要额外配置插件配置 `Role Claim:groups` 来让具有特定 `group` 的用户成为 Jellyfin 的管理员。

注意，需要额外配置插件配置 `Scheme Override:https` 来让 OAuth 正常工作。

注意，需要额外修改 CSS 设置和 HTML 设置来让登录页面隐藏正常的登录框，并显示 Authentik 的登录框。
