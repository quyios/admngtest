/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v21)
 *
 * LOGIC-ONLY BYPASS (Anti-Crash):
 * 1. Loại bỏ HOÀN TOÀN hook mạng (NSURLSession) để tránh xung đột PromiseKit.
 * 2. Hook trực tiếp vào các thuộc tính isRegistered, isAuthorized, isActivated.
 * 3. Duy trì UILabel và UIAlertController suppression để làm sạch giao diện.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// ─────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN   = @"13054349313ab35797213fc6df498da9589b7827ef7301e357bd73bacf6af77c";
static NSString *const kBYPASS_SECRET  = @"2677399ede86a2742b7097e53aa31ced59f435bc9267bf9da80cb4defcd16e78";
static NSString *const kSUCCESS_URL    = @"sileo://authentication_success?token=13054349313ab35797213fc6df498da9589b7827ef7301e357bd73bacf6af77c&payment_secret=2677399ede86a2742b7097e53aa31ced59f435bc9267bf9da80cb4defcd16e78";
static NSString *const kLOG_PATH       = @"/var/mobile/Media/1ferver/lua/script/log.txt";

static char const *const kCompBlockKeyV21 = "kCompBlockKeyV21";

// ─────────────────────────────────────────
// MARK: - Logging Helper
// ─────────────────────────────────────────

static void XXTLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *timestampMsg = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSLog(@"[XXT] %@", msg);
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLOG_PATH];
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
    }
}

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV21) @end
@implementation UILabel (BypassV21)
- (void)bp_v21_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (v21)";
    }
    [self bp_v21_setText:text];
}
@end

@interface UIViewController (BypassV21) @end
@implementation UIViewController (BypassV21)
- (void)bp_v21_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            XXTLog(@"Blocking 'Purchase Required' Alert. (v21)");
            if (cb) cb();
            return; 
        }
    }
    [self bp_v21_pv:vc animated:flag completion:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV21Bypass(void) {
    XXTLog(@"Applying Logic-Only Bypass v21 (Anti-Crash)...");
    
    // UI Override
    swizzle([UILabel class], @selector(setText:), @selector(bp_v21_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v21_pv:animated:completion:));

    // XXTEMoreLicenseController (Logic Hijack)
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        class_replaceMethod(LC, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isActivated),  imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }

    // HVCHavocAccount (Account Hijack)
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(token), imp_implementationWithBlock(^id(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(HA, @selector(secret), imp_implementationWithBlock(^id(id self){ return kBYPASS_SECRET; }), "@@:");
        class_replaceMethod(HA, @selector(purchasedPackages), imp_implementationWithBlock(^id(id self){ 
            return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; 
        }), "@@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, id arg){ return YES; }), "B@:@");
    }

    // ASWebAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompBlockKeyV21, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompBlockKeyV21);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV21Bypass();
    }
}
