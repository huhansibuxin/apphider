// AppHider — 极简应用隐藏 tweak（rootless / roothide 双版本）
//
// 原理（已用本机 iOS16 头文件验证）：
//   1) hook SBIconModel 的 -isIconVisible:  (SBIconModel.h:15，iOS16 仍是 SBHIconModel 子类)
//      → 模型层闸门，对隐藏列表里的 bundle id 返回 NO。
//   2) 双保险：同时 hook SBIconController 的
//      -iconManager:isIconVisibleForBundleIdentifier:  (SBIconController.h:448)
//      → 这个回调直接拿到 bundle id 字符串，再 gate 一次，首测成功率最高。
//
// 隐藏列表：/var/mobile/Library/Preferences/com.huhansibuxin.apphider.plist
//   { "apps" = ( "com.tencent.wetype", ... ); "debug" = 0/1; }
// 编辑后 post Darwin 通知 "com.huhansibuxin.apphider/reload" 或 respring 生效。
//
// 日后合并进 airpods-volume：把下面 %hook SBIconModel / %hook SBIconController
// 两段 + AHReloadHiddenApps() + %ctor 里的 reload 注册，直接丢进 airpods-volume
// 的 SB hook 文件即可，零新增依赖、零新增注入目标。
//
// ============================================================
// ⬇⬇⬇ 以下为「可移植片段」，合并时整体复制 ⬇⬇⬇
// ============================================================

#import <Foundation/Foundation.h>

static NSString *const kAHDomain   = @"com.huhansibuxin.apphider";
static NSString *const kAHReloadNote = @"com.huhansibuxin.apphider/reload";

static NSSet<NSString *> *ah_hiddenApps = nil;
static BOOL ah_debug = NO;

static NSString *AHLogPath(void) {
    return @"/var/mobile/Documents/apphider_debug.log";
}

// 极简文件日志：仅在 debug=1 时写，避免污染（诊断用，符合老板设备上文件日志惯例）
static void AHLog(NSString *fmt, ...) {
    if (!ah_debug) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n",
                      [[NSDate date] description], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:AHLogPath()];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } else {
        [line writeToFile:AHLogPath() atomically:YES
                 encoding:NSUTF8StringEncoding error:nil];
    }
}

static void AHReloadHiddenApps(void) {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kAHDomain];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *apps = prefs[@"apps"];
    ah_hiddenApps = ([apps isKindOfClass:[NSArray class]] ? [NSSet setWithArray:apps] : [NSSet set]);
    ah_debug = [prefs[@"debug"] boolValue];
    AHLog(@"reload: %lu hidden apps", (unsigned long)ah_hiddenApps.count);
}

// Darwin 通知（跨进程）：设置面板/手动改 plist 后 post 此通知即可热重载，无需 respring
static void AHReloadCallback(CFNotificationCenterRef center, void *observer,
                            CFStringRef name, const void *object, CFDictionaryRef info) {
    AHReloadHiddenApps();
}

%ctor {
    AHReloadHiddenApps();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, AHReloadCallback, (__bridge CFStringRef)kAHReloadNote,
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    AHLog(@"AppHider loaded");
}

// ---- 主闸门：模型层 ----
%hook SBIconModel
- (BOOL)isIconVisible:(id)arg0 {
    if (ah_hiddenApps && ah_hiddenApps.count) {
        NSString *bid = nil;
        if ([arg0 respondsToSelector:@selector(applicationBundleID)])
            bid = [arg0 performSelector:@selector(applicationBundleID)];
        if (bid && [ah_hiddenApps containsObject:bid]) {
            AHLog(@"hide(model) %@", bid);
            return NO;
        }
    }
    return %orig;
}
%end

// ---- 双保险：控制器层直接拿 bundle id ----
%hook SBIconController
- (BOOL)iconManager:(id)arg0 isIconVisibleForBundleIdentifier:(id)arg1 {
    if (ah_hiddenApps && ah_hiddenApps.count &&
        [arg1 isKindOfClass:[NSString class]] &&
        [ah_hiddenApps containsObject:arg1]) {
        AHLog(@"hide(ctrl) %@", arg1);
        return NO;
    }
    return %orig;
}
%end

// ============================================================
// ⬆⬆⬆ 可移植片段结束 ⬆⬆⬆
// ============================================================
