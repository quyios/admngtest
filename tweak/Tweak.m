/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v15)
 *
 * SỬA LỖI V14: Khôi phục Category và cấu trúc hook chuẩn. 
 * 1. Chặn DRM từ 82flex.com và havoc.app.
 * 2. Ép UI hiển thị "Registered".
 * 3. Chặn Alert "Purchase Required".
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

static char const *const kCompletionBlockKeyV15 = "kCompletionBlockKeyV15";

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
    NSDictionary *pkg = @{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS", @"purchased": @YES};
    NSDictionary *d = @{
        @"status": @"success",
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

@interface UILabel (BypassV15) @end
@implementation UILabel (BypassV15)
- (void)bp_v15_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active (TrollStore)";
    }
    [self bp_v15_setText:text];
}
@end

@interface UIViewController (BypassV15) @end
@implementation UIViewController (BypassV15)
- (void)bp_v15_pv:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))cb {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *a = (UIAlertController *)vc;
        if ([a.title containsString:@"Purchase Required"] || [a.message containsString:@"XXTouch Elite TS"]) {
            if (cb) cb();
            return; 
        }
    }
    [self bp_v15_pv:vc animated:flag completion:cb];
}
@end

@interface NSURLSession (BypassV15) @end
@implementation NSURLSession (BypassV15)
- (NSURLSessionDataTask *)bp_v15_dtwr:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    NSString *url = req.URL.absoluteString;
    if ([url containsString:@"havoc.app"] || [url containsString:@"82flex.com"]) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeDRMResponse(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v15_dtwr:req completionHandler:cb];
}
@end

// ─────────────────────────────────────────
// MARK: - Fake Account Object
// ─────────────────────────────────────────

@interface XXTFakeAccountV15 : NSObject @end
@implementation XXTFakeAccountV15
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

static void applyV15Bypass(void) {
    NSLog(@"[XXT] Applying Bypass v15...");
    
    // UI
    swizzle([UILabel class], @selector(setText:), @selector(bp_v15_setText:));
    swizzle([UIViewController class], @selector(presentViewController:animated:completion:), @selector(bp_v15_pv:animated:completion:));

    // Network
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v15_dtwr:completionHandler:));

    // ASWebAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        class_replaceMethod(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL* u, id s, id cb){
             objc_setAssociatedObject(self, kCompletionBlockKeyV15, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
             return self;
        }), "@@:@@@");
        class_replaceMethod(AS, @selector(start), imp_implementationWithBlock(^BOOL(id self){
             void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV15);
             if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
             return YES;
        }), "B@:");
    }

    // Account
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        id fake = [XXTFakeAccountV15 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV15Bypass();
    }
}
