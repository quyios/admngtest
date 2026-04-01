/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v5)
 *
 * FORCE SILEO TOKENS: Sử dụng token và secret thật từ Havoc API.
 * Hook ASWebAuthenticationSession để tự động bypass redirect.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AuthenticationServices/AuthenticationServices.h>

// ─────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN  = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL   = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";

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
        @"token": kBYPASS_TOKEN,
        @"payment_secret": kBYPASS_SECRET,
        @"license_status": @"registered"
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Fake Account Object
// ─────────────────────────────────────────

@interface XXTFakeAccount : NSObject @end
@implementation XXTFakeAccount
- (BOOL)isValid         { return YES; }
- (BOOL)isAuthenticated { return YES; }
- (BOOL)isAuthorized    { return YES; }
- (BOOL)isRegistered    { return YES; }
- (BOOL)isActivated     { return YES; }
- (NSString *)token     { return kBYPASS_TOKEN; }
- (NSString *)secret    { return kBYPASS_SECRET; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

// ─────────────────────────────────────────
// MARK: - Hooks Implementations
// ─────────────────────────────────────────

@interface XXTBypassHooks : NSObject @end
@implementation XXTBypassHooks
+ (id)sharedInstance { return [XXTFakeAccount new]; }
+ (id)currentAccount { return [XXTFakeAccount new]; }
+ (id)account        { return [XXTFakeAccount new]; }
+ (BOOL)accountExists { return YES; }

- (BOOL)isTrue  { return YES; }
- (id)emptyArr  { return @[[NSObject new]]; }
- (id)bypassToken  { return kBYPASS_TOKEN; }
- (id)bypassSecret { return kBYPASS_SECRET; }
- (void)doNothing {}
@end

// ─────────────────────────────────────────
// MARK: - ASWebAuthenticationSession Hook
// ─────────────────────────────────────────

@interface ASWebAuthBypass : NSObject @end
@implementation ASWebAuthBypass

- (BOOL)bp_start {
    // Intercept ASWebAuthenticationSession và trả về success ngay lập tức
    // Trình duyệt sẽ không hiện popup login.
    id session = self;
    id block = [session valueForKey:@"completionHandler"];
    if (block) {
        void (^completion)(NSURL *, NSError *) = block;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:kSUCCESS_URL], nil);
        });
    }
    return YES; 
}

@end

// ─────────────────────────────────────────
// MARK: - NSURLSession Hook
// ─────────────────────────────────────────

@interface NSURLSession (BypassV5) @end
@implementation NSURLSession (BypassV5)
- (NSURLSessionDataTask *)bp_v5_dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    if (isBypassHost(req.URL.host)) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeOKJSON(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v5_dataTaskWithRequest:req completionHandler:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV5Bypass(void) {
    // 1. Hook HVCHavocAccount
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        Class metaclass = object_getClass(HA);
        swizzle(metaclass, @selector(currentAccount), @selector(currentAccount));
        swizzle(metaclass, @selector(account), @selector(account));
        swizzle(metaclass, @selector(sharedInstance), @selector(sharedInstance));
        swizzle(HA, @selector(isValid), @selector(isTrue));
        swizzle(HA, @selector(isAuthenticated), @selector(isTrue));
        swizzle(HA, @selector(token), @selector(bypassToken));
        swizzle(HA, @selector(secret), @selector(bypassSecret));
    }

    // 2. Hook HVCKeychainHelper
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzle(KC, @selector(accountExists), @selector(isTrue));
        swizzle(object_getClass(KC), @selector(accountExists), @selector(accountExists));
        swizzle(KC, @selector(token), @selector(bypassToken));
        swizzle(KC, @selector(secret), @selector(bypassSecret));
    }

    // 3. Hook XXTEMoreLicenseController
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(isAuthorized), @selector(isTrue));
        swizzle(LC, @selector(isRegistered), @selector(isTrue));
        swizzle(LC, @selector(isActivated),  @selector(isTrue));
        swizzle(LC, @selector(updateLicenseStatus), @selector(doNothing));
    }

    // 4. Hook ASWebAuthenticationSession
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        swizzle(AS, @selector(start), @selector(bp_start));
    }

    // 5. Hook NSURLSession
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v5_dataTaskWithRequest:completionHandler:));
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];
        
        applyV5Bypass();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyV5Bypass();
        }];
    }
}
