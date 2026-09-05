# AppHider (极简应用隐藏 tweak)

iOS 16 越狱环境下隐藏主屏 App 图标的极简 tweak。
原理：hook `SBIconModel -isIconVisible:`（模型层闸门）+ `SBIconController -iconManager:isIconVisibleForBundleIdentifier:`（双保险），对隐藏列表里的 bundle id 返回 `NO`。

> 这是从已装商业版 `me.liuming.apphider`（Paisseon/AppHider，GitHub 已 404、无公开源码）逆向后，**自己重写的等价实现**。包名用 `com.huhansibuxin.apphider`，与商业版并存互不冲突（测试时建议先卸商业版，避免双 dylib hook 同一方法混淆）。

## 构建

GitHub Actions 自动出 **rootless + roothide 双版本** `.deb`（`matrix: [rootless, roothide]`）：
- rootless 用官方 theos
- roothide 用 `github.com/roothide/theos` fork + `THEOS_PACKAGE_SCHEME=roothide`

push 后到 Actions 看构建，下载 Artifact 里的 `.deb`。

## 依赖

- **ellekit**（hook 引擎）
- **AltList**（`com.opa334.altlist`）：设置面板的「选择要隐藏的 App」用的是 AltList 的原生应用多选列表（`ATLApplicationListMultiSelectionController`，bundleless 用法，无需自定义 .bundle）。AltList 的枚举发生在你**打开选择器时**（Settings 进程内），SpringBoard 侧完全不枚举、零开销。

## 安装（TrollFools）

1. 先在 Sileo/Zebra 装好 **AltList**（依赖自动拉，但建议确认已装）。
2. 下载对应版本 `.deb`（roothide 设备选 roothide 变体）。
3. TrollFools 注入 `com.apple.springboard`（主屏）。
4. respring。

## 隐藏某个 App（走设置 UI）

1. 打开 iOS **设置 → AppHider → 选择要隐藏的 App**。
2. 在列表里勾选要隐藏的 App（顶部可搜索；副标题显示 bundle id）。
3. 返回、respring。被勾选的 App 图标即从主屏消失。

> 隐藏列表以 **bundle id 数组** 存于 `/var/mobile/Library/Preferences/com.huhansibuxin.apphider.plist` 的 `apps` 键。
> 改完建议 respring 让 SpringBoard 重新布局生效。

## 调试（验证 hook 命中）

设置里打开「诊断日志（debug）」，respring，然后：

```sh
ssh root@<设备> 'cat /var/mobile/Documents/apphider_debug.log'
# 应看到：hide(model) com.tencent.wetype / hide(ctrl) com.tencent.wetype
```

有 `hide(...)` 行即说明图标被成功拦截隐藏。

## 合并进 airpods-volume

`Tweak.xm` 中标记了「可移植片段」（⬇⬇⬇ / ⬆⬆⬆ 之间）：把两段 `%hook` + `AHReloadHiddenApps()` + `%ctor` 里的通知注册整段复制进 airpods-volume 的 SB hook 文件即可，零新增依赖、零新增注入目标。本设置面板（含 AltList 依赖）也可直接复用。
