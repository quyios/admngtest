/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v25)
 *
 * THE ULTIMATE NETWORK & LOGIC BYPASS (Daemon-Safe):
 * 1. Khôi phục ASWebAuthenticationSession hook (Block Havoc login popup).
 * 2. Đổi chiến thuật chặn mạng sang NSURLProtocol: An toàn tuyệt đối với PromiseKit, không gây crash!
 * 3. Bơm fake JSON cho mọi request đến 82flex/Havoc để đánh lừa Daemon E430.
 * 4. Gỡ Dependency UIKit Tĩnh (Sử dụng NSClassFromString) để Daemon CLI (ngserviced) không bị crash dyld.
 */

#import <Foundation/Foundation.h>
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
static char const *const kCompBlockKeyV25 = "kCompBlockKeyV25";

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

@interface XXTDummyProtocolV25 : NSURLProtocol @end
@implementation XXTDummyProtocolV25

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

@interface NSURLSessionConfiguration (BypassV25) @end
@implementation NSURLSessionConfiguration (BypassV25)
+ (NSURLSessionConfiguration *)bp_v25_defaultSessionConfiguration {
    NSURLSessionConfiguration *config = [self bp_v25_defaultSessionConfiguration]; // calls original
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray array];
    [protocols insertObject:[XXTDummyProtocolV25 class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}
+ (NSURLSessionConfiguration *)bp_v25_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = [self bp_v25_ephemeralSessionConfiguration]; // calls original
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray array];
    [protocols insertObject:[XXTDummyProtocolV25 class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Account Property Methods
// ─────────────────────────────────────────

static id fakeToken(id self, SEL _cmd) { return kBYPASS_TOKEN; }
static id fakeSecret(id self, SEL _cmd) { return kBYPASS_SECRET; }
static id fakePackages(id self, SEL _cmd) { return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; }
static BOOL fakeAlwaysTrue(id self, SEL _cmd, ...) { return YES; }

// ─────────────────────────────────────────
// MARK: - UI hooks using C functions (No UIKit dependency)
// ─────────────────────────────────────────

static void (*orig_setText)(id self, SEL _cmd, NSString *text);
static void bp_v25_setText(id self, SEL _cmd, NSString *text) {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (v25)";
    }
    if (orig_setText) orig_setText(self, _cmd, text);
}

static void (*orig_presentViewController)(id self, SEL _cmd, id vc, BOOL animated, void (^completion)(void));
static void bp_v25_presentViewController(id self, SEL _cmd, id vc, BOOL animated, void (^completion)(void)) {
    if (vc && [vc isKindOfClass:NSClassFromString(@"UIAlertController")]) {
        NSString *title = [vc valueForKey:@"title"];
        NSString *msg = [vc valueForKey:@"message"];
        if ((title && [title containsString:@"Purchase Required"]) || (msg && [msg containsString:@"XXTouch Elite TS"])) {
            XXTLog(@"Blocked 'Purchase Required' Alert!");
            if (completion) completion();
            return; 
        }
    }
    if (orig_presentViewController) orig_presentViewController(self, _cmd, vc, animated, completion);
}

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV25Bypass(void) {
    XXTLog(@"--- STARTING ULTIMATE BYPASS v25 ---");
    
    // 1. NSURLProtocol Network Hook (Safe for PromiseKit)
    [NSURLProtocol registerClass:[XXTDummyProtocolV25 class]];
    swizzleClass([NSURLSessionConfiguration class], @selector(defaultSessionConfiguration), @selector(bp_v25_defaultSessionConfiguration));
    swizzleClass([NSURLSessionConfiguration class], @selector(ephemeralSessionConfiguration), @selector(bp_v25_ephemeralSessionConfiguration));

    // 2. UI Hook (Safe Dynamic)
    Class UILabelClass = NSClassFromString(@"UILabel");
    if (UILabelClass) {
        Method m = class_getInstanceMethod(UILabelClass, @selector(setText:));
        if (m) {
            orig_setText = (void (*)(id, SEL, NSString *))method_getImplementation(m);
            method_setImplementation(m, (IMP)bp_v25_setText);
        }
    }
    Class UIViewControllerClass = NSClassFromString(@"UIViewController");
    if (UIViewControllerClass) {
        Method m = class_getInstanceMethod(UIViewControllerClass, @selector(presentViewController:animated:completion:));
        if (m) {
            orig_presentViewController = (void (*)(id, SEL, id, BOOL, void(^)(void)))method_getImplementation(m);
            method_setImplementation(m, (IMP)bp_v25_presentViewController);
        }
    }

    // 3. ASWebAuth Hook (Fixes the popup issue in v23)
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompBlockKeyV25, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             XXTLog(@"Simulating ASWebAuth success.");
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompBlockKeyV25);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }

    // 4. Shotgun Swizzler (Runtime logic overrides) - REMOVED isValid, isActivated to prevent daemon hang
    NSArray *boolTargets = @[@"isAuthorized", @"isRegistered", @"isAuthenticated", @"hasPurchasedPackageWithIdentifier:"];
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
