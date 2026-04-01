/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v4)
 *
 * SỬA LỖI: Data type mismatch và thiếu singleton hooks.
 * Đảm bảo hiển thị "Registered" và email bypass@offline.local.
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

static BOOL isBypassHost(NSString *host) {
    if (!host) return NO;
    NSString *h = [host lowercaseString];
    return [h containsString:@"82flex.com"] || [h containsString:@"havoc.app"] || [h containsString:@"xxtou.ch"];
}

static NSData *fakeOKJSON(void) {
    NSDictionary *d = @{
        @"status": @"ok",
        @"valid": @YES,
        @"authenticated": @YES,
        @"authorized": @YES,
        @"registered": @YES,
        @"activated": @YES,
        @"email": @"bypass@offline.local",
        @"username": @"BypassUser",
        @"license_status": @"registered"
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Bypass Classes
// ─────────────────────────────────────────

@interface XXTFakeAccount : NSObject
@end

@implementation XXTFakeAccount
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isActivated        { return YES; }
- (NSString *)token        { return @"bypass_token"; }
- (NSString *)secret       { return @"bypass_secret"; }
- (NSString *)email        { return @"bypass@offline.local"; }
- (NSString *)username     { return @"BypassUser"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

// Biến chứa selector gốc (nếu cần dùng)
@interface NSHTTPURLResponse (Bypass) @end
@implementation NSHTTPURLResponse (Bypass)
@end

// ─────────────────────────────────────────
// MARK: - Hook Implementations
// ─────────────────────────────────────────

@interface XXTBypassHooks : NSObject @end
@implementation XXTBypassHooks

// For HVCHavocAccount / HVCKeychainHelper
+ (id)sharedInstance { return [XXTFakeAccount new]; }
+ (id)currentAccount { return [XXTFakeAccount new]; }
+ (id)account        { return [XXTFakeAccount new]; }
+ (BOOL)accountExists { return YES; }

// Generic Status Hooks
- (BOOL)isTrue  { return YES; }
- (id)emptyArr  { return @[[NSObject new]]; }
- (id)bypassStr { return @"bypass_token"; }
- (void)doNothing {}

@end

// ─────────────────────────────────────────
// MARK: - NSURLSession Hook
// ─────────────────────────────────────────

@interface NSURLSession (BypassV4) @end
@implementation NSURLSession (BypassV4)

- (NSURLSessionDataTask *)bp_v4_dataTaskWithRequest:(NSURLRequest *)req 
                                  completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    if (isBypassHost(req.URL.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v4_dataTaskWithRequest:req completionHandler:cb];
}

@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyFinalBypass(void) {
    // 1. Hook HVCHavocAccount
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        swizzle(HA, @selector(isValid), @selector(isTrue));
        swizzle(HA, @selector(isAuthenticated), @selector(isTrue));
        swizzle(object_getClass(HA), @selector(currentAccount), @selector(currentAccount));
        swizzle(object_getClass(HA), @selector(account), @selector(account));
        swizzle(object_getClass(HA), @selector(sharedInstance), @selector(sharedInstance));
    }

    // 2. Hook HVCKeychainHelper
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzle(KC, @selector(accountExists), @selector(isTrue));
        swizzle(object_getClass(KC), @selector(accountExists), @selector(accountExists));
        swizzle(KC, @selector(token), @selector(bypassStr));
        swizzle(KC, @selector(secret), @selector(bypassStr));
    }

    // 3. Hook XXTEMoreLicenseController
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(isTrue));
        swizzle(LC, @selector(isRegistered), @selector(isTrue));
        swizzle(LC, @selector(isActivated),  @selector(isTrue));
        swizzle(LC, @selector(registeredViewers), @selector(emptyArr));
        swizzle(LC, @selector(updateLicenseStatus), @selector(doNothing));
    }

    // 4. Hook NSURLSession
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v4_dataTaskWithRequest:completionHandler:));
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        // Set UserDefaults Cache (Quan trọng để UI hiện email sớm)
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];

        applyFinalBypass();
        
        // Đảm bảo chạy lại sau khi app launch xong
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyFinalBypass();
        }];
    }
}
