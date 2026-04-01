/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v24)
 *
 * THE ULTIMATE NETWORK & LOGIC BYPASS:
 * 1. Khôi phục ASWebAuthenticationSession hook (Block Havoc login popup).
 * 2. Đổi chiến thuật chặn mạng sang NSURLProtocol: An toàn tuyệt đối với PromiseKit, không gây crash!
 * 3. Bơm fake JSON cho mọi request đến 82flex/Havoc để đánh lừa Daemon E430.
 * 4. Giữ nguyên Shotgun Swizzler và UI Suppression.
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
static NSString *const kLOG_PATH       = @"/tmp/xxt_bypass.log";
static char const *const kCompBlockKeyV24 = "kCompBlockKeyV24";

// ─────────────────────────────────────────
// MARK: - Logging Helper
// ─────────────────────────────────────────

static void XXTLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *timestampMsg = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSLog(@"[XXT_BYPASS] %@", msg);
    
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

static void swizzle(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getInstanceMethod(cls, original);
    Method replMethod = class_getInstanceMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
        XXTLog(@"Core Swizzled -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original));
    }
}

static void swizzleClass(Class cls, SEL original, SEL replacement) {
    if (!cls) return;
    Method origMethod = class_getClassMethod(cls, original);
    Method replMethod = class_getClassMethod(cls, replacement);
    if (origMethod && replMethod) {
        method_exchangeImplementations(origMethod, replMethod);
        XXTLog(@"Core Swizzled +[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original));
    }
}

// ─────────────────────────────────────────
// MARK: - Safe Network Protocol Interceptor
// ─────────────────────────────────────────

@interface XXTDummyProtocolV24 : NSURLProtocol @end
@implementation XXTDummyProtocolV24

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    return ([url containsString:@"havoc.app"] || [url containsString:@"82flex.com"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSString *url = self.request.URL.absoluteString;
    XXTLog(@"[NSURLProtocol] Intercepting: %@", url);
    
    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    NSDictionary *pkg = @{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS", @"purchased": @YES};
    NSDictionary *d = @{
        @"timestamp": @((long long)ts),
        @"status": @(200),
        @"result": @"success",
        @"success": @YES,
        @"data": @{
            @"is_activated": @YES, @"is_registered": @YES, @"license_type": @"elite",
            @"expiry_date": @"2099-01-01", @"packages": @[pkg],
            @"user": @{@"email": @"bypass@offline.local", @"username": @"EliteUser"},
            @"entitlements": @[pkg]
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
    
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading { }

@end

@interface NSURLSessionConfiguration (BypassV24) @end
@implementation NSURLSessionConfiguration (BypassV24)
+ (NSURLSessionConfiguration *)bp_v24_defaultSessionConfiguration {
    NSURLSessionConfiguration *config = [self bp_v24_defaultSessionConfiguration]; // calls original
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray array];
    [protocols insertObject:[XXTDummyProtocolV24 class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}
+ (NSURLSessionConfiguration *)bp_v24_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = [self bp_v24_ephemeralSessionConfiguration]; // calls original
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray array];
    [protocols insertObject:[XXTDummyProtocolV24 class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}
@end

// ─────────────────────────────────────────
// MARK: - UI & Flow Suppression
// ─────────────────────────────────────────

@interface UILabel (BypassV24) @end
@implementation UILabel (BypassV24)
- (void)bp_v24_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (v24)";
    }
    [self bp_v24_setText:text];
}
@end

@interface UIViewController (BypassV24) @end
@implementation UIViewController (BypassV24)
- (void)bp_v24_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            XXTLog(@"Blocked 'Purchase Required' Alert!");
            if (cb) cb();
            return; 
        }
    }
    [self bp_v24_pv:vc animated:flag completion:cb];
}
@end

static id fakeToken(id self, SEL _cmd) { return kBYPASS_TOKEN; }
static id fakeSecret(id self, SEL _cmd) { return kBYPASS_SECRET; }
static id fakePackages(id self, SEL _cmd) { return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; }
static BOOL fakeAlwaysTrue(id self, SEL _cmd, ...) { return YES; }

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV24Bypass(void) {
    XXTLog(@"--- STARTING ULTIMATE BYPASS v24 ---");
    
    // 1. NSURLProtocol Network Hook (Safe for PromiseKit)
    [NSURLProtocol registerClass:[XXTDummyProtocolV24 class]];
    swizzleClass([NSURLSessionConfiguration class], @selector(defaultSessionConfiguration), @selector(bp_v24_defaultSessionConfiguration));
    swizzleClass([NSURLSessionConfiguration class], @selector(ephemeralSessionConfiguration), @selector(bp_v24_ephemeralSessionConfiguration));

    // 2. UI Hook
    swizzle([UILabel class], @selector(setText:), @selector(bp_v24_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v24_pv:animated:completion:));

    // 3. ASWebAuth Hook (Fixes the popup issue in v23)
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompBlockKeyV24, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             XXTLog(@"Simulating ASWebAuth success.");
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompBlockKeyV24);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }

    // 4. Shotgun Swizzler (Runtime logic overrides)
    NSArray *boolTargets = @[@"isAuthorized", @"isRegistered", @"isActivated", @"isValid", @"isAuthenticated", @"hasPurchasedPackageWithIdentifier:"];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            if ([className hasPrefix:@"XXT"] || [className hasPrefix:@"HVC"] || 
                [className containsString:@"License"] || [className containsString:@"Auth"] || [className containsString:@"Daemon"]) {
                for (NSString *selStr in boolTargets) {
                    SEL sel = NSSelectorFromString(selStr);
                    Method m = class_getInstanceMethod(cls, sel);
                    if (m && method_getTypeEncoding(m)[0] == 'B') class_replaceMethod(cls, sel, (IMP)fakeAlwaysTrue, method_getTypeEncoding(m));
                    Method cm = class_getClassMethod(cls, sel);
                    if (cm && method_getTypeEncoding(cm)[0] == 'B') class_replaceMethod(object_getClass(cls), sel, (IMP)fakeAlwaysTrue, method_getTypeEncoding(cm));
                }
                if ([className isEqualToString:@"HVCHavocAccount"]) {
                    class_replaceMethod(cls, NSSelectorFromString(@"token"), (IMP)fakeToken, "@@:");
                    class_replaceMethod(cls, NSSelectorFromString(@"secret"), (IMP)fakeSecret, "@@:");
                    class_replaceMethod(cls, NSSelectorFromString(@"purchasedPackages"), (IMP)fakePackages, "@@:");
                }
            }
        }
        free(classes);
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool { applyV24Bypass(); }
}
