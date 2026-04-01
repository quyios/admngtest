/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v12)
 *
 * DEEP NETWORK INTERCEPT:
 * 1. Chặn request POST /api/sileo/user_info.
 * 2. Trả về JSON giả lập có sẵn gói "XXTouch Elite TS".
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// ─────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN   = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET  = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL    = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kELITE_PACKAGE  = @"ch.xxtou.xxtouch.elitets";

static char const *const kCompletionBlockKeyV12 = "kCompletionBlockKeyV12";

// ─────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────

static void swizzle(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, original);
    Method replMethod = class_getInstanceMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
    }
}

static NSData *fakeUserInfoJSON(void) {
    NSDictionary *pkg = @{
        @"identifier": kELITE_PACKAGE,
        @"name": @"XXTouch Elite TS",
        @"purchased": @YES,
        @"status": @"purchased"
    };
    NSDictionary *d = @{
        @"status": @"success",
        @"success": @YES,
        @"data": @{
            @"user": @{@"email":@"bypass@offline.local", @"username":@"BypassUser"},
            @"packages": @[pkg],
            @"entitlements": @[pkg]
        },
        @"packages": @[pkg]
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Fake Models
// ─────────────────────────────────────────

@interface XXTFakePackageV12 : NSObject @end
@implementation XXTFakePackageV12
- (NSString *)identifier { return kELITE_PACKAGE; }
- (NSString *)name       { return @"XXTouch Elite TS"; }
- (BOOL)isPurchased      { return YES; }
@end

@interface XXTFakeAccountV12 : NSObject @end
@implementation XXTFakeAccountV12
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (NSString *)token        { return kBYPASS_TOKEN; }
- (NSString *)secret       { return kBYPASS_SECRET; }
- (NSString *)email        { return @"bypass@offline.local"; }
- (NSArray *)purchasedPackages { return @[[XXTFakePackageV12 new]]; }
- (BOOL)hasPurchasedPackageWithIdentifier:(id)ident { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV12) @end
@implementation UILabel (BypassV12)
- (void)bp_v12_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite License Active (Verified)";
    }
    [self bp_v12_setText:text];
}
@end

@interface NSURLSession (BypassV12) @end
@implementation NSURLSession (BypassV12)
- (NSURLSessionDataTask *)bp_v12_dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    NSString *url = req.URL.absoluteString;
    if ([url containsString:@"havoc.app/api/sileo/user_info"]) {
        NSLog(@"[XXT] Intercepted user_info POST request.");
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeUserInfoJSON(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v12_dataTaskWithRequest:req completionHandler:cb];
}
@end

@interface NSObject (BypassV12) @end
@implementation NSObject (BypassV12)
- (id)bp_v12_initASAuth:(NSURL *)url callbackURLScheme:(id)s completionHandler:(id)cb {
    id instance = [self bp_v12_initASAuth:url callbackURLScheme:s completionHandler:cb];
    if (instance && cb) objc_setAssociatedObject(instance, kCompletionBlockKeyV12, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return instance;
}
- (BOOL)bp_v12_startASAuth {
    void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV12);
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
        return YES;
    }
    return [self bp_v12_startASAuth];
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV12Bypass(void) {
    swizzle([UILabel class], @selector(setText:), @selector(bp_v12_setText:));
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v12_dataTaskWithRequest:completionHandler:));

    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    for (NSString *name in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(name);
        if (cls) {
            swizzle(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_v12_initASAuth:callbackURLScheme:completionHandler:));
            swizzle(cls, @selector(start), @selector(bp_v12_startASAuth));
        }
    }

    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        id fake = [XXTFakeAccountV12 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(HA, @selector(purchasedPackages), imp_implementationWithBlock(^NSArray*(id self){ return @[[XXTFakePackageV12 new]]; }), "@@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, id ident){ return YES; }), "B@:@");
    }
    
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        class_replaceMethod(LC, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d synchronize];
        applyV12Bypass();
    }
}
