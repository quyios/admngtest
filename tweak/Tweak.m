/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v22)
 *
 * THE SAFE UI-ONLY STRATEGY:
 * 1. KHÔNG HOOK NETWORK (NSURLSession) để tránh crash do PromiseKit.
 * 2. Chỉ Bịt miệng Alert (UI Suppression).
 * 3. Ép nội dung Label.
 * 4. Fake Account properties.
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
    
    // Write to /tmp for easy access via Filza if needed
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
// MARK: - Safe Swizzle
// ─────────────────────────────────────────

static void swizzle(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, original);
    Method replMethod = class_getInstanceMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
        XXTLog(@"Swizzled -[%@ %@] with -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original), NSStringFromClass(cls), NSStringFromSelector(replacement));
    }
}

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV22) @end
@implementation UILabel (BypassV22)
- (void)bp_v22_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (TrollStore - v22)";
    }
    [self bp_v22_setText:text];
}
@end

@interface UIViewController (BypassV22) @end
@implementation UIViewController (BypassV22)
- (void)bp_v22_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        // Bắt chính xác thông báo lỗi mua hàng
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            XXTLog(@"Blocked 'Purchase Required' Alert!");
            if (cb) cb();
            return; // Im lặng bỏ qua
        }
    }
    [self bp_v22_pv:vc animated:flag completion:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Account Object
// ─────────────────────────────────────────

@interface XXTFakeAccountV22 : NSObject @end
@implementation XXTFakeAccountV22
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (NSString *)token        { return kBYPASS_TOKEN; }
- (NSString *)secret       { return kBYPASS_SECRET; }
- (id)purchasedPackages    { return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; }
- (BOOL)hasPurchasedPackageWithIdentifier:(id)ident { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV22Bypass(void) {
    XXTLog(@"Applying Safe UI-Only Bypass v22...");
    
    // 1. Hook UI để làm sạch giao diện và chặn Alert
    swizzle([UILabel class], @selector(setText:), @selector(bp_v22_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v22_pv:animated:completion:));

    // 2. Hook Data Logic: Chỉ thay thế các thuộc tính của Tài Khoản và Controller (Safe)
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        class_replaceMethod(LC, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isActivated),  imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        XXTLog(@"Hooked XXTEMoreLicenseController");
    }

    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        id fake = [XXTFakeAccountV22 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, id arg){ return YES; }), "B@:@");
        XXTLog(@"Hooked HVCHavocAccount");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV22Bypass();
    }
}
