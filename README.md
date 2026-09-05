# AppHider (极简应用隐藏 tweak)

iOS 16 越狱环境下隐藏主屏 App 图标的极简 tweak。
原理：hook `SBIconModel -isIconVisible:`（模型层闸门）+ `SBIconController -iconManager:isIconVisibleForBundleIdentifier:`（双保险），对隐藏列表里的 bundle id 返回 `NO`。

> 这是从已装商业版 `me.liuming.apphider`（Paisseon/AppHider，GitHub 已 404、无公开源码）逆向后，**自己重写的等价实现**。包名用 `com.huhansibuxin.apphider`，与商业版并存互不冲突（测试时建议先卸商业版，避免双 dylib hook 同一方法混淆）。

## 构建

GitHub Actions 自动出 **rootless + roothide 双版本** `.deb`（`matrix: [rootless, roothide]`）：
- rootless 用官方 theos
- roothide 用 `github.com/roothide/theos` fork + `THEOS_PACKAGE_SCHEME=roothide`

push 后到 Actions 看构建，下载 Artifact 里的 `.deb`。

## 安装（TrollFools）

1. 下载对应版本的 `.deb`（roothide 设备选 roothide 变体）。
2. TrollFools 注入 `com.apple.springboard`（主屏）。
3. respring 生效。

## 隐藏某个 App

编辑设备上的 `/var/mobile/Library/Preferences/com.huhansibuxin.apphider.plist`：

```xml
<dict>
    <key>apps</key>
    <array>
        <string>com.tencent.wetype</string>
    </array>
    <key>debug</key>
    <false/>
</dict>
```

改完在终端 post Darwin 通知热重载（无需 respring）：

```sh
# 设备上（或 ssh）
killall -SIGUSR1 不需要; # 实际用:
# 通过 notify_post 触发，或简单 respring:
sbreload   # 或 killall backboardd
```

> 简化：直接 respring 最稳。debug=1 时会在 `/var/mobile/Documents/apphider_debug.log` 记录每次命中隐藏，方便验证 hook 是否生效。

## 调试（验证 hook 命中）

把 plist 的 `debug` 设为 `1`（或 `true`），respring，然后：

```sh
ssh root@<设备> 'cat /var/mobile/Documents/apphider_debug.log'
# 应看到：hide(model) com.tencent.wetype / hide(ctrl) com.tencent.wetype
```

有 `hide(...)` 行即说明图标被成功拦截隐藏。

## 合并进 airpods-volume

`Tweak.xm` 中标记了「可移植片段」（⬇⬇⬇ / ⬆⬆⬆ 之间）：把两段 `%hook` + `AHReloadHiddenApps()` + `%ctor` 里的通知注册整段复制进 airpods-volume 的 SB hook 文件即可，零新增依赖、零新增注入目标。
