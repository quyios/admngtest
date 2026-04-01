/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v14)
 *
 * 82FLEX DRM INTERCEPT:
 * 1. Chặn request đến drm.82flex.com/api/v2/device_info_ts.
 * 2. Trả về JSON Elite vĩnh viễn.
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

static char const *const kCompletionBlockKeyV14 = "kCompletionBlockKeyV14";

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
// MARK: - Fake Responses
// ─────────────────────────────────────────

static NSData *fakeDRMResponse(void) {
    NSDictionary *d = @{
        @"status": @"success",
        @"success": @YES,
        @"data": @{
            @"is_activated": @YES,
            @"is_registered": @YES,
            @"license_type": @"elite",
            @"expiry_date": @"2099-01-01",
            @"email": @"bypass@offline.local",
            @"packages": @[@"ch.xxtou.xxtouch.elitets", @"xxtouchelitets"]
        }
    };
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

// ─────────────────────────────────────────
// MARK: - Hooks Implementation
// ─────────────────────────────────────────

@interface XXTUIHooksV14 : NSObject @end
@implementation XXTUIHooksV14

// Intercept Alerts
- (void)bp_v14_presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)vc;
        if ([alert.title containsString:@"Purchase Required"] || [alert.message containsString:@"XXTouch Elite TS"]) {
            if (completion) completion();
            return; 
        }
    }
    [self bp_v14_presentViewController:vc animated:flag completion:completion];
}

// Intercept Labels
- (void)bp_v14_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (TrollStore)";
    }
    [self bp_v14_setText:text];
}

@end

@interface NSURLSession (BypassV14) @end
@implementation NSURLSession (BypassV14)

- (NSURLSessionDataTask *)bp_v14_dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    NSString *url = req.URL.absoluteString;
    // Chặn cả Havoc user_info và 82Flex device_info_ts
    if ([url containsString:@"havoc.app/api/sileo/user_info"] || [url containsString:@"82flex.com/api/v2/device_info_ts"]) {
        NSLog(@"[XXT] Intercepted DRM/Auth Request: %@", url);
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeDRMResponse(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v14_dataTaskWithRequest:req completionHandler:cb];
}

@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV14Bypass(void) {
    // UI Suppression
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v14_presentViewController:animated:completion:));
    swizzle([UILabel class], @selector(setText:), @selector(bp_v14_setText:));

    // Network Intercept
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v14_dataTaskWithRequest:completionHandler:));

    // ASWebAuth Bypass
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompletionBlockKeyV14, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV14);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }

    // Account & Keychain
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return [self new]; }), "@@:"); // Return self as fake or similar
        class_replaceMethod(HA, @selector(isValid), (IMP)imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), (IMP)imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(purchasedPackages), (IMP)imp_implementationWithBlock(^NSArray*(id self){ 
            return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; 
        }), "@@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV14Bypass();
    }
}
