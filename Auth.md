# Aiursoft 所有基础设施使用 Authentik 来进行统一身份验证

## OpenWeb Chat

* 基于 OpenId Connect 协议。
* Client ID 和 Client Secret 需要通过环境变量传递给 OpenWeb Chat 服务。
* 无法继承任何权限信息。所有权限在本地配置。
* 在合并用户时自动根据 Email 进行匹配。
* 注销时只会注销 OpenWeb Chat 的会话，不会影响 Authentik 的会话。