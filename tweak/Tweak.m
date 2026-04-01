/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v6)
 *
 * DEEP ASWEBAUTH HOOK: 
 * Bắt lấy callback từ hàm khởi tạo ASWebAuthenticationSession.
 * Tự động kích hoạt thành công khi app yêu cầu đăng nhập.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ─────────────────────────────────────────
// MARK: - Constants & Tokens
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN  = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL   = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";

static char const *const kCompletionBlockKey = "kCompletionBlockKey";

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

// ─────────────────────────────────────────
// MARK: - ASWebAuthenticationSession Hook
// ─────────────────────────────────────────

@interface ASWebAuthBypassV6 : NSObject @end
@implementation ASWebAuthBypassV6

- (id)bp_initWithURL:(NSURL *)url 
   callbackURLScheme:(NSString *)scheme 
   completionHandler:(void (^)(NSURL *, NSError *))completion {
    id instance = [self bp_initWithURL:url callbackURLScheme:scheme completionHandler:completion];
    if (instance && completion) {
        // Lưu lại block để dùng khi start() được gọi
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
        return YES; // Đã xử lý xong, không cần hiện UI
    }
    return [self bp_start]; // Gọi gốc nếu không có block (không nên xảy ra)
}

@end

// ─────────────────────────────────────────
// MARK: - Fake Objects & Other Hooks
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

@interface XXTBypassHooks : NSObject @end
@implementation XXTBypassHooks
+ (id)bp_shared { return [XXTFakeAccount new]; }
- (BOOL)isTrue  { return YES; }
- (id)emptyArr  { return @[[NSObject new]]; }
- (id)bp_token  { return kBYPASS_TOKEN; }
- (id)bp_secret { return kBYPASS_SECRET; }
- (void)doNothing {}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV6Bypass(void) {
    // 1. Hook ASWebAuthenticationSession
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        swizzle(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_initWithURL:callbackURLScheme:completionHandler:));
        swizzle(AS, @selector(start), @selector(bp_start));
    }

    // 2. Hook SFAuthenticationSession (cho các bản iOS cũ hơn hoặc app dùng bản cũ)
    Class SF = NSClassFromString(@"SFAuthenticationSession");
    if (SF) {
        swizzle(SF, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_initWithURL:callbackURLScheme:completionHandler:));
        swizzle(SF, @selector(start), @selector(bp_start));
    }

    // 3. Hook HVCHavocAccount / HVCKeychainHelper
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

    // 4. Hook XXTEMoreLicenseController
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(isTrue));
        swizzle(LC, @selector(isRegistered), @selector(isTrue));
        swizzle(LC, @selector(updateLicenseStatus), @selector(doNothing));
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];
        
        applyV6Bypass();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyV6Bypass();
        }];
    }
}
