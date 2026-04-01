/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v3)
 *
 * FULL UI BYPASS: Chuyển trạng thái sang "Registered" hoàn toàn.
 * Fix lỗi "Unauthorized device" và "Not Registered".
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

static void swizzleClass(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Class metaclass = object_getClass(cls);
    Method origMethod = class_getInstanceMethod(metaclass, original);
    Method replMethod = class_getInstanceMethod(metaclass, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
    }
}

static BOOL isBypassHost(NSString *host) {
    if (!host) return NO;
    return [host containsString:@"drm.82flex.com"] || 
           [host containsString:@"havoc.app"] ||
           [host containsString:@"xxtou.ch"];
}

static NSData *fakeOKJSON(void) {
    NSDictionary *d = @{
        @"status": @"ok",
        @"valid": @YES,
        @"authenticated": @YES,
        @"authorized": @YES,
        @"registered": @YES,
        @"activated": @YES,
        @"device_id": @"bypass_device_id",
        @"license_status": @"registered"
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Fake Objects
// ─────────────────────────────────────────

@interface HVCFakeAccount : NSObject @end
@implementation HVCFakeAccount
- (BOOL)isValid         { return YES; }
- (BOOL)isAuthenticated { return YES; }
- (BOOL)isAuthorized    { return YES; }
- (BOOL)isRegistered    { return YES; }
- (BOOL)isActivated     { return YES; }
- (NSString *)token     { return @"bypass_token_offline_xxt"; }
- (NSString *)secret    { return @"bypass_secret_offline_xxt"; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSString *)username  { return @"Bypass User"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; } // Trả về đã có thiết bị đăng ký
@end

// ─────────────────────────────────────────
// MARK: - Controller Bypass
// ─────────────────────────────────────────

@interface XXTEBypassController : NSObject @end
@implementation XXTEBypassController
- (BOOL)bp_isAuthorized { return YES; }
- (BOOL)bp_isRegistered { return YES; }
- (BOOL)bp_isActivated  { return YES; }
- (void)bp_presence_updateLicenseStatus {}
- (NSArray *)bp_registeredViewers { return @[[NSObject new]]; }
@end

// ─────────────────────────────────────────
// MARK: - Account/Keychain Bypass
// ─────────────────────────────────────────

@interface HVCHavocBypass : NSObject @end
@implementation HVCHavocBypass
+ (id)bp_currentAccount { return [HVCFakeAccount new]; }
+ (id)bp_account        { return [HVCFakeAccount new]; }
+ (id)bp_sharedInstance { return [HVCFakeAccount new]; }
- (BOOL)bp_isValid         { return YES; }
- (BOOL)bp_isAuthenticated { return YES; }
- (BOOL)bp_isRegistered    { return YES; }
+ (BOOL)bp_accountExists   { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - NSURLSession Bypass
// ─────────────────────────────────────────

@interface NSURLSession (BypassV3) @end
@implementation NSURLSession (BypassV3)

- (NSURLSessionDataTask *)bp_v3_dataTaskWithRequest:(NSURLRequest *)req 
                                  completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    if (isBypassHost(req.URL.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v3_dataTaskWithRequest:req completionHandler:cb];
}

@end

// ─────────────────────────────────────────
// MARK: - Apply All
// ─────────────────────────────────────────

static void applyV3Bypass(void) {
    // ── HVCHavocAccount ──
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        swizzleClass(HA, @selector(currentAccount), @selector(bp_currentAccount));
        swizzleClass(HA, @selector(account), @selector(bp_account));
        swizzleClass(HA, @selector(sharedInstance), @selector(bp_sharedInstance));
        swizzle(HA, @selector(isValid), @selector(bp_isValid));
        swizzle(HA, @selector(isAuthenticated), @selector(bp_isAuthenticated));
        swizzle(HA, @selector(isRegistered), @selector(bp_isRegistered));
        swizzle(HA, @selector(registeredViewers), @selector(bp_registeredViewers));
    }

    // ── HVCKeychainHelper ──
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzleClass(KC, @selector(accountExists), @selector(bp_accountExists));
        swizzle(KC, @selector(accountExists), @selector(bp_accountExists));
        // Ép các hàm token/secret trả về bypass string
        swizzle(KC, @selector(token), @selector(bp_isValid)); // Mượn bp_isValid trả về YES? No, cần string.
    }

    // ── XXTEMoreLicenseController ──
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(bp_isAuthorized));
        swizzle(LC, @selector(isRegistered), @selector(bp_isRegistered));
        swizzle(LC, @selector(isActivated), @selector(bp_isActivated));
        swizzle(LC, @selector(updateLicenseStatus), @selector(bp_presence_updateLicenseStatus));
        // Hook các biến Viewer
        swizzle(LC, @selector(registeredViewers), @selector(bp_registeredViewers));
    }

    // ── NSURLSession ──
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v3_dataTaskWithRequest:completionHandler:));
}

// ─────────────────────────────────────────
// MARK: - Constructor
// ─────────────────────────────────────────

__attribute__((constructor))
static void dylib_main(void) {
    @autoreleasepool {
        // Set UserDefaults Cache
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];

        applyV3Bypass();

        // Hook lại khi app đã sẵn sàng (đảm bảo không bị override)
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyV3Bypass();
        }];
    }
}
