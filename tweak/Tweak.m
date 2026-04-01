/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v20)
 *
 * LOGGING TÍCH HỢP:
 * 1. Ghi log ra file /var/mobile/Media/1ferver/lua/script/log.txt.
 * 2. Sửa lỗi biên dịch v19 (unused variable).
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
static NSString *const kLOG_PATH       = @"/var/mobile/Media/1ferver/lua/script/log.txt";

static char const *const kCompBlockKeyV20 = "kCompBlockKeyV20";

// ─────────────────────────────────────────
// MARK: - Logging Helper
// ─────────────────────────────────────────

static void XXTLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *timestampMsg = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSLog(@"[XXT] %@", msg);
    
    // Ghi vào file log.txt
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLOG_PATH];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:kLOG_PATH contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:kLOG_PATH];
    }
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[timestampMsg dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    }
}

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
// MARK: - Fake Data
// ─────────────────────────────────────────

static NSData *fakeDRMResponse(void) {
    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    NSDictionary *pkg = @{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS", @"purchased": @YES};
    NSDictionary *d = @{
        @"timestamp": @((long long)ts),
        @"status": @(200),
        @"result": @"success",
        @"success": @YES,
        @"data": @{
            @"is_activated": @YES, @"is_registered": @YES, @"license_type": @"elite",
            @"expiry_date": @"2099-01-01", @"packages": @[pkg]
        }
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV20) @end
@implementation UILabel (BypassV20)
- (void)bp_v20_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (V20)";
    }
    [self bp_v20_setText:text];
}
@end

@interface UIViewController (BypassV20) @end
@implementation UIViewController (BypassV20)
- (void)bp_v20_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            XXTLog(@"Blocking 'Purchase Required' Alert.");
            if (cb) cb();
            return; 
        }
    }
    [self bp_v20_pv:vc animated:flag completion:cb];
}
@end

@interface NSURLSession (BypassV20) @end
@implementation NSURLSession (BypassV20)
- (NSURLSessionDataTask *)bp_v20_dtwr:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    NSString *url = req.URL.absoluteString;
    if ([url containsString:@"havoc.app"] || [url containsString:@"82flex.com"]) {
        XXTLog(@"Intercepting request: %@", url);
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeDRMResponse(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v20_dtwr:req completionHandler:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Account Object
// ─────────────────────────────────────────

@interface XXTFakeAccountV20 : NSObject @end
@implementation XXTFakeAccountV20
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (NSString *)token        { return kBYPASS_TOKEN; }
- (NSString *)secret       { return kBYPASS_SECRET; }
- (id)purchasedPackages    { return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets"}]; }
- (BOOL)hasPurchasedPackageWithIdentifier:(id)ident { return YES; }
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV20Bypass(void) {
    XXTLog(@"Applying Bypass v20 (Logging + Stabilized)...");
    
    // UI
    swizzle([UILabel class], @selector(setText:), @selector(bp_v20_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v20_pv:animated:completion:));

    // Network
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v20_dtwr:completionHandler:));

    // ASWebAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompBlockKeyV20, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             XXTLog(@"Simulating ASWebAuth success.");
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompBlockKeyV20);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }

    // Account
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        id fake = [XXTFakeAccountV20 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV20Bypass();
    }
}
