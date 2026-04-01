/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v13)
 *
 * HARDCORE UI SUPPRESSION:
 * 1. Chặn đứng UIAlertController "Purchase Required".
 * 2. Tự động "bấm" Later để app tiếp tục chạy.
 * 3. Ép Token thật của bạn vào mọi nơi.
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
static NSString *const kELITE_PACKAGE  = @"ch.xxtou.xxtouch.elitets";

static char const *const kCompletionBlockKeyV13 = "kCompletionBlockKeyV13";

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
// MARK: - UI Hooks (Hardcore Suppression)
// ─────────────────────────────────────────

@interface UIViewController (BypassV13) @end
@implementation UIViewController (BypassV13)

- (void)bp_v13_presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)vc;
        if ([alert.title containsString:@"Purchase Required"] || [alert.message containsString:@"XXTouch Elite TS"]) {
            NSLog(@"[XXT] Blocking 'Purchase Required' Alert.");
            if (completion) completion();
            return; // Chặn đứng, không cho hiện
        }
    }
    [self bp_v13_presentViewController:vc animated:flag completion:completion];
}

@end

@interface UILabel (BypassV13) @end
@implementation UILabel (BypassV13)
- (void)bp_v13_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered (v13)";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (TrollStore Bypass)";
    }
    [self bp_v13_setText:text];
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Models
// ─────────────────────────────────────────

@interface XXTFakePackageV13 : NSObject @end
@implementation XXTFakePackageV13
- (id)identifier { return kELITE_PACKAGE; }
- (id)name       { return @"XXTouch Elite TS"; }
- (BOOL)isPurchased { return YES; }
@end

@interface XXTFakeAccountV13 : NSObject @end
@implementation XXTFakeAccountV13
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (NSString *)token        { return kBYPASS_TOKEN; }
- (NSString *)secret       { return kBYPASS_SECRET; }
- (NSArray *)purchasedPackages { return @[[XXTFakePackageV13 new]]; }
- (BOOL)hasPurchasedPackageWithIdentifier:(id)ident { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV13Bypass(void) {
    // 1. UI Suppression
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v13_presentViewController:animated:completion:));
    swizzle([UILabel class], @selector(setText:), @selector(bp_v13_setText:));

    // 2. HVCHavocAccount & HVCKeychainHelper
    id HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        id fake = [XXTFakeAccountV13 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(HA, @selector(purchasedPackages), imp_implementationWithBlock(^id(id self){ return @[[XXTFakePackageV13 new]]; }), "@@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, id i){ return YES; }), "B@:@");
    }

    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        class_replaceMethod(KC, @selector(token), imp_implementationWithBlock(^id(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(KC, @selector(secret), imp_implementationWithBlock(^id(id self){ return kBYPASS_SECRET; }), "@@:");
    }

    // 3. ASWebAuth / SFAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    for (NSString *name in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(name);
        if (cls) {
            class_replaceMethod(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
                 objc_setAssociatedObject(self, kCompletionBlockKeyV13, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
                 return self;
            }), "@@:@@@");
            class_replaceMethod(cls, @selector(start), imp_implementationWithBlock(^BOOL(id self){
                 void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV13);
                 if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
                 return YES;
            }), "B@:");
        }
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV13Bypass();
    }
}
