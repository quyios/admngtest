/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v23)
 *
 * THE SHOTGUN SWIZZLER STRATEGY:
 * 1. Không dùng Network Hook để tránh crash nền (giữ nguyên độ ổn định v22).
 * 2. Giữ nguyên UI Suppression (bịt miệng UIAlert "Purchase Required").
 * 3. Duyệt toàn bộ Class trong Runtime. Tìm các Class liên quan đến XXTouch/License.
 * 4. Hook tự động tất cả các hàm kiểm duyệt (isRegistered, isAuthorized, isValid...) trả về YES.
 * 5. Bẻ gãy lỗi "E430: This device is not authorized..." từ tận gốc rễ daemons.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ─────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN   = @"13054349313ab35797213fc6df498da9589b7827ef7301e357bd73bacf6af77c";
static NSString *const kBYPASS_SECRET  = @"2677399ede86a2742b7097e53aa31ced59f435bc9267bf9da80cb4defcd16e78";
static NSString *const kLOG_PATH       = @"/tmp/xxt_bypass.log";

// ─────────────────────────────────────────
// MARK: - Logging Helper
// ─────────────────────────────────────────

static void XXTLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *timestampMsg = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSLog(@"[XXT_BYPASS] %@", msg);
    
    // Ghi log để theo dõi chính xác hàm nào bị Shotgun bắn trúng
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLOG_PATH];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:kLOG_PATH contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:kLOG_PATH];
    }
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[timestampMsg dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    }
}

// ─────────────────────────────────────────
// MARK: - Classic Safe Swizzle
// ─────────────────────────────────────────

static void swizzle(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, original);
    Method replMethod = class_getInstanceMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
        XXTLog(@"Core Swizzled -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original));
    }
}

// ─────────────────────────────────────────
// MARK: - UI Suppression (from v22)
// ─────────────────────────────────────────

@interface UILabel (BypassV23) @end
@implementation UILabel (BypassV23)
- (void)bp_v23_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (TrollStore - v23)";
    }
    [self bp_v23_setText:text];
}
@end

@interface UIViewController (BypassV23) @end
@implementation UIViewController (BypassV23)
- (void)bp_v23_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            XXTLog(@"Blocked 'Purchase Required' Alert!");
            if (cb) cb();
            return; 
        }
    }
    [self bp_v23_pv:vc animated:flag completion:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Account Property Methods
// ─────────────────────────────────────────

static id fakeToken(id self, SEL _cmd) { return kBYPASS_TOKEN; }
static id fakeSecret(id self, SEL _cmd) { return kBYPASS_SECRET; }
static id fakePackages(id self, SEL _cmd) { return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; }
static BOOL fakeAlwaysTrue(id self, SEL _cmd, ...) { return YES; }

// ─────────────────────────────────────────
// MARK: - The Shotgun Swizzler
// ─────────────────────────────────────────

static void applyShotgunBypass(void) {
    XXTLog(@"--- STARTING SHOTGUN SWIZZLER v23 ---");
    
    // 1. Hook UI để làm sạch giao diện và chặn Alert
    swizzle([UILabel class], @selector(setText:), @selector(bp_v23_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v23_pv:animated:completion:));

    // Các hàm mục tiêu cần đổi thành YES (trả về kiểu BOOL)
    NSArray *boolTargets = @[@"isAuthorized", @"isRegistered", @"isActivated", @"isValid", @"isAuthenticated", @"hasPurchasedPackageWithIdentifier:"];
    
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            
            // Lọc các Class khả nghi: Bắt đầu bằng XXT, HVC, hoặc có chữ License, Auth, Daemon
            if ([className hasPrefix:@"XXT"] || [className hasPrefix:@"HVC"] || 
                [className containsString:@"License"] || [className containsString:@"Auth"] || [className containsString:@"Daemon"]) {
                
                // A. Shotgun phương thức trả về BOOL
                for (NSString *selStr in boolTargets) {
                    SEL sel = NSSelectorFromString(selStr);
                    
                    // Instance Methods
                    Method m = class_getInstanceMethod(cls, sel);
                    if (m) {
                        const char *type = method_getTypeEncoding(m);
                        if (type && (type[0] == 'B' || type[0] == 'c')) {
                            class_replaceMethod(cls, sel, (IMP)fakeAlwaysTrue, type);
                            XXTLog(@"[X] Hijacked Instance Method -[%@ %@]", className, selStr);
                        }
                    }
                    
                    // Class Methods
                    Method cm = class_getClassMethod(cls, sel);
                    if (cm) {
                        const char *type = method_getTypeEncoding(cm);
                        if (type && (type[0] == 'B' || type[0] == 'c')) {
                            class_replaceMethod(object_getClass(cls), sel, (IMP)fakeAlwaysTrue, type);
                            XXTLog(@"[X] Hijacked Class Method +[%@ %@]", className, selStr);
                        }
                    }
                }
                
                // B. Shotgun các thuộc tính Token/Secret của HavocAccount
                if ([className isEqualToString:@"HVCHavocAccount"]) {
                    class_replaceMethod(cls, NSSelectorFromString(@"token"), (IMP)fakeToken, "@@:");
                    class_replaceMethod(cls, NSSelectorFromString(@"secret"), (IMP)fakeSecret, "@@:");
                    class_replaceMethod(cls, NSSelectorFromString(@"purchasedPackages"), (IMP)fakePackages, "@@:");
                    class_replaceMethod(object_getClass(cls), NSSelectorFromString(@"currentAccount"), imp_implementationWithBlock(^id(id self){
                        id fakeObj = [[cls alloc] init];
                        return fakeObj;
                    }), "@@:");
                    XXTLog(@"[X] Hijacked HVCHavocAccount Properties");
                }
            }
        }
        free(classes);
    }
    XXTLog(@"--- SHOTGUN SWIZZLER DONE ---");
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyShotgunBypass();
    }
}
