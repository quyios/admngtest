/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition
 *
 * KHÔNG dùng Logos / CydiaSubstrate / Substitute
 * Dùng ObjC Runtime thuần (method_exchangeImplementations)
 * → chạy được trên TrollStore không cần jailbreak
 *
 * Hook targets:
 *   HVCKeychainHelper   - trả token/secret giả, accountExists = YES
 *   HVCHavocAccount     - isValid/isAuthenticated = YES
 *   HVCHavocSecret      - isValid/isVerified = YES
 *   XXTEMoreLicenseController - disable purchase alerts
 *   NSURLSession        - block drm.82flex.com + havoc.app
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
    // Instance không có thì thử class method
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
    return [host containsString:@"drm.82flex.com"] ||
           [host containsString:@"havoc.app"];
}

static NSData *fakeOKJSON(void) {
    NSDictionary *d = @{@"status": @"ok", @"valid": @YES, @"authenticated": @YES};
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - HVCKeychainHelper swizzle methods
// ─────────────────────────────────────────

@interface HVCKeychainHelper_Bypass : NSObject @end
@implementation HVCKeychainHelper_Bypass

+ (BOOL)bypass_accountExists { return YES; }
- (BOOL)bypass_accountExists { return YES; }
- (NSString *)bypass_token { return @"bypass_token_offline_xxt"; }
- (NSString *)bypass_secret { return @"bypass_secret_offline_xxt"; }
+ (NSString *)bypass_tokenForKey:(NSString *)k { return @"bypass_token_offline_xxt"; }
+ (NSString *)bypass_secretForKey:(NSString *)k { return @"bypass_secret_offline_xxt"; }
- (NSString *)bypass_tokenForKey:(NSString *)k { return @"bypass_token_offline_xxt"; }
- (NSString *)bypass_secretForKey:(NSString *)k { return @"bypass_secret_offline_xxt"; }

- (void)bypass_removeAccountFromKeychain:(NSString *)k completion:(void(^)(BOOL))cb {
    if (cb) cb(YES);
}
- (void)bypass_saveAccountWithToken:(NSString *)t secret:(NSString *)s completion:(void(^)(BOOL, NSError *))cb {
    if (cb) cb(YES, nil);
}
- (id)bypass_loadAccountWithCompletion:(void(^)(id, NSError *))cb {
    if (cb) cb([NSObject new], nil);
    return self;
}

@end

// ─────────────────────────────────────────
// MARK: - HVCHavocAccount / HVCHavocSecret swizzle
// ─────────────────────────────────────────

@interface HVCAccount_Bypass : NSObject @end
@implementation HVCAccount_Bypass
- (BOOL)bypass_isValid         { return YES; }
- (BOOL)bypass_isAuthenticated { return YES; }
- (NSString *)bypass_token     { return @"bypass_token_offline_xxt"; }
- (NSString *)bypass_secret    { return @"bypass_secret_offline_xxt"; }
@end

// ─────────────────────────────────────────
// MARK: - XXTEMoreLicenseController swizzle
// ─────────────────────────────────────────

@interface License_Bypass : NSObject @end
@implementation License_Bypass
- (void)bypass_presentPurchaseAlert    {}   // no-op
- (void)bypass_redirectToPurchasePage  {}   // no-op
- (void)bypass_redirectToMyPurchasesPage {}
- (void)bypass_updateLicenseDictionary:(id)d {}
@end

// ─────────────────────────────────────────
// MARK: - NSURLSession block DRM / Havoc
// ─────────────────────────────────────────

@interface NSURLSession (Bypass) @end
@implementation NSURLSession (Bypass)

- (NSURLSessionDataTask *)bypass_dataTaskWithRequest:(NSURLRequest *)request
                                   completionHandler:(void(^)(NSData *, NSURLResponse *, NSError *))cb {
    if (isBypassHost(request.URL.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
                initWithURL:request.URL statusCode:200
                HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        // trả task không làm gì
        return [self bypass_dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]
                              completionHandler:nil];
    }
    return [self bypass_dataTaskWithRequest:request completionHandler:cb];
}

- (NSURLSessionDataTask *)bypass_dataTaskWithURL:(NSURL *)url
                               completionHandler:(void(^)(NSData *, NSURLResponse *, NSError *))cb {
    if (isBypassHost(url.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
                initWithURL:url statusCode:200
                HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        return [self bypass_dataTaskWithURL:[NSURL URLWithString:@"about:blank"] completionHandler:nil];
    }
    return [self bypass_dataTaskWithURL:url completionHandler:cb];
}

@end

// ─────────────────────────────────────────
// MARK: - Apply all swizzles
// ─────────────────────────────────────────

static void applySwizzles(void) {

    // ── HVCKeychainHelper ──
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    Class KC_bp = [HVCKeychainHelper_Bypass class];
    if (KC) {
        swizzle(KC, @selector(accountExists), @selector(bypass_accountExists));
        swizzle(KC, @selector(token), @selector(bypass_token));
        swizzle(KC, @selector(secret), @selector(bypass_secret));
        swizzle(KC, @selector(tokenForKey:), @selector(bypass_tokenForKey:));
        swizzle(KC, @selector(secretForKey:), @selector(bypass_secretForKey:));
        swizzle(KC, @selector(removeAccountFromKeychain:completion:),
                @selector(bypass_removeAccountFromKeychain:completion:));
        swizzle(KC, @selector(saveAccountWithToken:secret:completion:),
                @selector(bypass_saveAccountWithToken:secret:completion:));
        swizzle(KC, @selector(loadAccountWithCompletion:),
                @selector(bypass_loadAccountWithCompletion:));
        // class methods
        swizzleClass(KC, @selector(accountExists), @selector(bypass_accountExists));
        swizzleClass(KC, @selector(tokenForKey:), @selector(bypass_tokenForKey:));
        swizzleClass(KC, @selector(secretForKey:), @selector(bypass_secretForKey:));
    }
    (void)KC_bp;

    // ── HVCHavocAccount ──
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        Class bp = [HVCAccount_Bypass class];
        swizzle(HA, @selector(isValid),         @selector(bypass_isValid));
        swizzle(HA, @selector(isAuthenticated),  @selector(bypass_isAuthenticated));
        swizzle(HA, @selector(token),            @selector(bypass_token));
        swizzle(HA, @selector(secret),           @selector(bypass_secret));
        (void)bp;
    }

    // ── HVCHavocSecret ──
    Class HS = NSClassFromString(@"HVCHavocSecret");
    if (HS) {
        Class bp = [HVCAccount_Bypass class];
        swizzle(HS, @selector(isValid),    @selector(bypass_isValid));
        swizzle(HS, @selector(isVerified), @selector(bypass_isAuthenticated));
        swizzle(HS, @selector(secret),     @selector(bypass_secret));
        (void)bp;
    }

    // ── XXTEMoreLicenseController ──
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        Class bp = [License_Bypass class];
        swizzle(LC, @selector(presentPurchaseAlert),       @selector(bypass_presentPurchaseAlert));
        swizzle(LC, @selector(redirectToPurchasePage),     @selector(bypass_redirectToPurchasePage));
        swizzle(LC, @selector(redirectToMyPurchasesPage),  @selector(bypass_redirectToMyPurchasesPage));
        swizzle(LC, @selector(updateLicenseDictionary:),   @selector(bypass_updateLicenseDictionary:));
        (void)bp;
    }

    // ── NSURLSession ──
    Class SES = [NSURLSession class];
    swizzle(SES,
        @selector(dataTaskWithRequest:completionHandler:),
        @selector(bypass_dataTaskWithRequest:completionHandler:));
    swizzle(SES,
        @selector(dataTaskWithURL:completionHandler:),
        @selector(bypass_dataTaskWithURL:completionHandler:));
}

// ─────────────────────────────────────────
// MARK: - Constructor (chạy khi dylib load)
// ─────────────────────────────────────────

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        // Set NSUserDefaults cache keys
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (![d objectForKey:@"kXXTEMoreLicenseCachedEmail"])
            [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        if (![d objectForKey:@"kXXTEMoreLicenseCachedLicense"])
            [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];

        // Swizzle ngay khi load nếu class đã có
        applySwizzles();

        // Observer: swizzle lại khi class load muộn hơn (dynamic frameworks)
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *n) {
                        applySwizzles();
                    }];
    }
}
