/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v7)
 *
 * ULTIMATE LOGIN BYPASS: 
 * 1. Dlopen AuthenticationServices để đảm bảo hook chạy được.
 * 2. Chặn UIApplication openURL để tóm lấy lệnh mở link Havoc.
 * 3. Tự động phản hồi bằng sileo://success token.
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

static char const *const kCompletionBlockKey = "kCompletionBlockKeyV7";

// ─────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────

static void swizzle(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, original);
    Method replMethod = class_getInstanceMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
        return;
    }
    origMethod = class_getClassMethod(cls, original);
    replMethod = class_getClassMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
    }
}

static BOOL isAuthURL(NSURL *url) {
    if (!url) return NO;
    NSString *abs = [url.absoluteString lowercaseString];
    return [abs containsString:@"havoc.app/api/sileo/authenticate"] || 
           [abs containsString:@"havoc.app/auth/signin"];
}

// ─────────────────────────────────────────
// MARK: - Hooks Implementations
// ─────────────────────────────────────────

@interface XXTFakeAccount : NSObject @end
@implementation XXTFakeAccount
- (BOOL)isValid         { return YES; }
- (BOOL)isAuthenticated { return YES; }
- (BOOL)isAuthorized    { return YES; }
- (BOOL)isRegistered    { return YES; }
- (NSString *)token     { return kBYPASS_TOKEN; }
- (NSString *)secret    { return kBYPASS_SECRET; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

@interface XXTBypassHooksV7 : NSObject @end
@implementation XXTBypassHooksV7

// ASWebAuthenticationSession / SFAuthenticationSession
- (id)bp_initWithURL:(NSURL *)url callbackURLScheme:(NSString *)scheme completionHandler:(void (^)(NSURL *, NSError *))completion {
    id instance = [self bp_initWithURL:url callbackURLScheme:scheme completionHandler:completion];
    if (instance && completion) {
        objc_setAssociatedObject(instance, kCompletionBlockKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return instance;
}

- (BOOL)bp_start {
    void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKey);
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:kSUCCESS_URL], nil);
        });
        return YES;
    }
    return [self bp_start];
}

// Singleton hooks
+ (id)bp_shared { return [XXTFakeAccount new]; }
- (BOOL)isTrue  { return YES; }
- (id)bp_token  { return kBYPASS_TOKEN; }
- (id)bp_secret { return kBYPASS_SECRET; }

@end

// ─────────────────────────────────────────
// MARK: - UIApplication Hook (Intercept OpenURL)
// ─────────────────────────────────────────

@interface UIApplication (BypassV7) @end
@implementation UIApplication (BypassV7)

- (void)bp_openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey,id> *)options completionHandler:(void (^)(BOOL))completion {
    if (isAuthURL(url)) {
        NSLog(@"[XXT] Intercepted Havoc Auth URL: %@", url);
        // Thay vì mở Safari, ta "bắn" ngược lại link thành công cho app
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[XXT] Triggering success callback...");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kSUCCESS_URL] options:@{} completionHandler:nil];
        });
        if (completion) completion(YES);
        return;
    }
    [self bp_openURL:url options:options completionHandler:completion];
}

@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV7Bypass(void) {
    // Đảm bảo framework đã load
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    dlopen("/System/Library/Frameworks/SafariServices.framework/SafariServices", RTLD_NOW);

    // 1. ASWebAuthenticationSession / SFAuthenticationSession
    for (NSString *clsName in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(clsName);
        if (cls) {
            swizzle(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_initWithURL:callbackURLScheme:completionHandler:));
            swizzle(cls, @selector(start), @selector(bp_start));
        }
    }

    // 2. UIApplication openURL
    swizzle([UIApplication class], @selector(openURL:options:completionHandler:), @selector(bp_openURL:options:completionHandler:));

    // 3. HVCHavocAccount / HVCKeychainHelper
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        swizzle(object_getClass(HA), @selector(currentAccount), @selector(bp_shared));
        swizzle(object_getClass(HA), @selector(sharedInstance), @selector(bp_shared));
        swizzle(HA, @selector(isValid), @selector(isTrue));
        swizzle(HA, @selector(isAuthenticated), @selector(isTrue));
        swizzle(HA, @selector(token), @selector(bp_token));
        swizzle(HA, @selector(secret), @selector(bp_secret));
    }

    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzle(object_getClass(KC), @selector(accountExists), @selector(isTrue));
        swizzle(KC, @selector(accountExists), @selector(isTrue));
        swizzle(KC, @selector(token), @selector(bp_token));
        swizzle(KC, @selector(secret), @selector(bp_secret));
    }

    // 4. XXTEMoreLicenseController
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(isTrue));
        swizzle(LC, @selector(isRegistered), @selector(isTrue));
        swizzle(LC, @selector(updateLicenseStatus), @selector(isTrue)); // hook làm gì đó trả về YES
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];
        
        applyV7Bypass();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyV7Bypass();
        }];
    }
}
