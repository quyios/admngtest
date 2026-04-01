/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v10)
 *
 * SURGICAL UI BYPASS:
 * 1. Chặn "Not Registered" tại UILabel setText.
 * 2. Chặn "Unauthorized device" tại TableView Footer.
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

static NSString *const kBYPASS_TOKEN  = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL   = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";

static char const *const kCompletionBlockKeyV10 = "kCompletionBlockKeyV10";

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
// MARK: - Fake Account
// ─────────────────────────────────────────

@interface XXTFakeAccountV10 : NSObject @end
@implementation XXTFakeAccountV10
- (BOOL)isValid         { return YES; }
- (BOOL)isAuthenticated { return YES; }
- (BOOL)isRegistered    { return YES; }
- (BOOL)isAuthorized    { return YES; }
- (NSString *)token     { return kBYPASS_TOKEN; }
- (NSString *)secret    { return kBYPASS_SECRET; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV10) @end
@implementation UILabel (BypassV10)
- (void)bp_v10_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) {
            text = @"Registered";
        } else if ([text containsString:@"Unauthorized device"]) {
            text = @"Device Authorized (XXT Bypass v10)";
        }
    }
    [self bp_v10_setText:text];
}
@end

@interface UIViewController (BypassV10) @end
@implementation UIViewController (BypassV10)
- (NSString *)bp_v10_tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    NSString *orig = [self bp_v10_tableView:tv titleForFooterInSection:s];
    if ([orig containsString:@"Unauthorized device"]) {
        return @"Enjoy Elite Features (Bypassed)";
    }
    return orig;
}
@end

@interface NSObject (BypassV10) @end
@implementation NSObject (BypassV10)
- (id)bp_v10_initWithURL:(NSURL *)url callbackURLScheme:(id)s completionHandler:(id)cb {
    id instance = [self bp_v10_initWithURL:url callbackURLScheme:s completionHandler:cb];
    if (instance && cb) {
        objc_setAssociatedObject(instance, kCompletionBlockKeyV10, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return instance;
}

- (BOOL)bp_v10_start {
    void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV10);
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:kSUCCESS_URL], nil);
        });
        return YES;
    }
    return [self bp_v10_start];
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV10Bypass(void) {
    // 1. UILabel Text
    swizzle([UILabel class], @selector(setText:), @selector(bp_v10_setText:));
    
    // 2. License Controller Footer & BOOL Hooks
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(tableView:titleForFooterInSection:), @selector(bp_v10_tableView:titleForFooterInSection:));
        class_replaceMethod(LC, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }

    // 3. ASWebAuth / SFAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    for (NSString *name in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(name);
        if (cls) {
            swizzle(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_v10_initWithURL:callbackURLScheme:completionHandler:));
            swizzle(cls, @selector(start), @selector(bp_start)); // Note: if swizzled to bp_v10_start, check method names
            // Actually, keep it simple for v10
            class_replaceMethod(cls, @selector(start), imp_implementationWithBlock(^BOOL(id self){
                void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV10);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
                    return YES;
                }
                return YES;
            }), "B@:");
        }
    }

    // 4. Accounts & Keychain
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return [XXTFakeAccountV10 new]; }), "@@:");
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }

    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        class_replaceMethod(KC, @selector(token), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(KC, @selector(secret), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_SECRET; }), "@@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d synchronize];
        applyV10Bypass();
    }
}
