/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v2)
 *
 * Đã sửa lỗi: Dylib load nhưng UI vẫn báo "Not Registered"
 * Bổ sung: Hook các hàm Class Method (Singleton) để trả về Account giả lập thay vì nil.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ─────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────

static void swizzle(Class cls, SEL original, SEL replacement) {
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
    Class metaclass = object_getClass(cls);
    Method origMethod = class_getInstanceMethod(metaclass, original);
    Method replMethod = class_getInstanceMethod(metaclass, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
    }
}

static BOOL isBypassHost(NSString *host) {
    if (!host) return NO;
    return [host containsString:@"drm.82flex.com"] || [host containsString:@"havoc.app"];
}

static NSData *fakeOKJSON(void) {
    NSDictionary *d = @{@"status": @"ok", @"valid": @YES, @"authenticated": @YES, @"authorized": @YES};
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
- (NSString *)token     { return @"bypass_token_offline_xxt"; }
- (NSString *)secret    { return @"bypass_secret_offline_xxt"; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSString *)username  { return @"bypass_user"; }
@end

@interface HVCFakeSecret : NSObject @end
@implementation HVCFakeSecret
- (BOOL)isValid         { return YES; }
- (BOOL)isVerified      { return YES; }
- (NSString *)secret    { return @"bypass_secret_offline_xxt"; }
@end

// ─────────────────────────────────────────
// MARK: - HVCKeychainHelper Swizzles
// ─────────────────────────────────────────

@interface HVCKeychainHelper_Bypass : NSObject @end
@implementation HVCKeychainHelper_Bypass
+ (BOOL)bp_accountExists { return YES; }
- (BOOL)bp_accountExists { return YES; }
- (NSString *)bp_token   { return @"bypass_token_offline_xxt"; }
- (NSString *)bp_secret  { return @"bypass_secret_offline_xxt"; }
+ (NSString *)bp_tokenForKey:(id)k { return @"bypass_token_offline_xxt"; }
+ (NSString *)bp_secretForKey:(id)k { return @"bypass_secret_offline_xxt"; }
- (id)bp_loadAccountWithCompletion:(void(^)(id,id))cb { if(cb) cb([HVCFakeAccount new], nil); return [HVCFakeAccount new]; }
@end

// ─────────────────────────────────────────
// MARK: - HVCHavocAccount Swizzles
// ─────────────────────────────────────────

@interface HVCHavocAccount_Bypass : NSObject @end
@implementation HVCHavocAccount_Bypass
+ (id)bp_currentAccount { return [HVCFakeAccount new]; }
+ (id)bp_account        { return [HVCFakeAccount new]; }
+ (id)bp_sharedInstance { return [HVCFakeAccount new]; }
- (BOOL)bp_isValid         { return YES; }
- (BOOL)bp_isAuthenticated { return YES; }
- (BOOL)bp_isAuthorized    { return YES; }
- (BOOL)bp_isRegistered    { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - XXTEMoreLicenseController Swizzles
// ─────────────────────────────────────────

@interface XXTEMoreLicense_Bypass : NSObject @end
@implementation XXTEMoreLicense_Bypass
- (BOOL)bp_isAuthorized { return YES; }
- (BOOL)bp_isRegistered { return YES; }
- (BOOL)bp_isActivated  { return YES; }
- (void)bp_updateLicenseStatus {}
- (void)bp_presentPurchaseAlert {}
@end

// ─────────────────────────────────────────
// MARK: - NSURLSession Swizzles
// ─────────────────────────────────────────

@interface NSURLSession_Bypass : NSObject @end
@implementation NSURLSession_Bypass
- (id)bp_dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    if (isBypassHost(req.URL.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_dataTaskWithRequest:req completionHandler:cb]; // original call
}
@end

// ─────────────────────────────────────────
// MARK: - Apply Hooks
// ─────────────────────────────────────────

static void applyBypass(void) {
    // ── HVCKeychainHelper ──
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzleClass(KC, @selector(accountExists), @selector(bp_accountExists));
        swizzle(KC, @selector(accountExists), @selector(bp_accountExists));
        swizzle(KC, @selector(token), @selector(bp_token));
        swizzle(KC, @selector(secret), @selector(bp_secret));
        swizzle(KC, @selector(loadAccountWithCompletion:), @selector(bp_loadAccountWithCompletion:));
        swizzleClass(KC, @selector(tokenForKey:), @selector(bp_tokenForKey:));
        swizzleClass(KC, @selector(secretForKey:), @selector(bp_secretForKey:));
    }

    // ── HVCHavocAccount ──
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        swizzleClass(HA, @selector(currentAccount), @selector(bp_currentAccount));
        swizzleClass(HA, @selector(account), @selector(bp_account));
        swizzleClass(HA, @selector(sharedInstance), @selector(bp_sharedInstance));
        swizzle(HA, @selector(isValid), @selector(bp_isValid));
        swizzle(HA, @selector(isAuthenticated), @selector(bp_isAuthenticated));
        swizzle(HA, @selector(isAuthorized), @selector(bp_isAuthorized));
        swizzle(HA, @selector(isRegistered), @selector(bp_isRegistered));
    }

    // ── HVCHavocSecret ──
    Class HS = NSClassFromString(@"HVCHavocSecret");
    if (HS) {
        swizzleClass(HS, @selector(secret), @selector(bp_sharedInstance)); // Reuse bp_sharedInstance to return fake object
        swizzle(HS, @selector(isValid), @selector(bp_isValid));
        swizzle(HS, @selector(isVerified), @selector(bp_isAuthenticated));
    }

    // ── XXTEMoreLicenseController ──
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(bp_isAuthorized));
        swizzle(LC, @selector(isRegistered), @selector(bp_isRegistered));
        swizzle(LC, @selector(isActivated),  @selector(bp_isActivated));
        swizzle(LC, @selector(updateLicenseStatus), @selector(bp_updateLicenseStatus));
        swizzle(LC, @selector(presentPurchaseAlert), @selector(bp_presentPurchaseAlert));
    }

    // ── NSURLSession ──
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_dataTaskWithRequest:completionHandler:));
}

// ─────────────────────────────────────────
// MARK: - Init
// ─────────────────────────────────────────

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        // Set Cache Emails
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];

        applyBypass();

        // Late-hook on Launch
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyBypass();
        }];
    }
}
