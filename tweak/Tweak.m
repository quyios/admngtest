/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v16)
 *
 * ANTI-CRASH & STABLE BYPASS:
 * 1. Loại bỏ các hook UI gây rủi ro (UIViewController).
 * 2. Chỉ hook vào các getter quan trọng của Account thay vì thay thế object.
 * 3. Duy trì chặn Network Intercept cho cả Havoc và 82Flex.
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

static char const *const kCompletionBlockKeyV16 = "kCompletionBlockKeyV16";

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
// MARK: - Fake Responses (Network)
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
// MARK: - Categories (Safe Hooks)
// ─────────────────────────────────────────

@interface UILabel (BypassV16) @end
@implementation UILabel (BypassV16)
- (void)bp_v16_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) text = @"Registered";
        else if ([text containsString:@"Unauthorized device"]) text = @"Elite Active";
    }
    [self bp_v16_setText:text];
}
@end

@interface NSURLSession (BypassV16) @end
@implementation NSURLSession (BypassV16)
- (NSURLSessionDataTask *)bp_v16_dtwr:(NSURLRequest *)req completionHandler:(void(^)(NSData*,NSURLResponse*,NSError*))cb {
    NSString *url = req.URL.absoluteString;
    if ([url containsString:@"havoc.app"] || [url containsString:@"82flex.com"]) {
        if (cb) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:req.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{ cb(fakeDRMResponse(), resp, nil); });
        }
        return [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    return [self bp_v16_dtwr:req completionHandler:cb];
}
@end

@interface NSObject (BypassV16) @end
@implementation NSObject (BypassV16)
- (id)bp_v16_initAS:(NSURL *)url callbackURLScheme:(id)s completionHandler:(id)cb {
    id instance = [self bp_v16_initAS:url callbackURLScheme:s completionHandler:cb];
    if (instance && cb) objc_setAssociatedObject(instance, kCompletionBlockKeyV16, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return instance;
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV16Bypass(void) {
    // 1. UILabel - Bảo vệ giao diện trực quan
    swizzle([UILabel class], @selector(setText:), @selector(bp_v16_setText:));

    // 2. Chặn đứng Network Intercept
    swizzle([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(bp_v16_dtwr:completionHandler:));

    // 3. ASWebAuthenticationSession / SFAuthenticationSession
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    for (NSString *name in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(name);
        if (cls) {
            swizzle(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_v16_initAS:callbackURLScheme:completionHandler:));
            class_replaceMethod(cls, @selector(start), imp_implementationWithBlock(^BOOL(id self){
                 void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV16);
                 if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
                 return YES;
            }), "B@:");
        }
    }

    // 4. Hook HVCHavocAccount - Phẫu thuật từng getter
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        // Cần đảm bảo Class method `currentAccount` không bị đè hoàn toàn để tránh crash
        // Thay vào đó ta hook các method instance của nó
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(token), imp_implementationWithBlock(^id(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(HA, @selector(secret), imp_implementationWithBlock(^id(id self){ return kBYPASS_SECRET; }), "@@:");
        class_replaceMethod(HA, @selector(purchasedPackages), imp_implementationWithBlock(^id(id self){ 
            return @[@{@"identifier": @"ch.xxtou.xxtouch.elitets", @"name": @"XXTouch Elite TS"}]; 
        }), "@@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, id arg){ return YES; }), "B@:@");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        applyV16Bypass();
    }
}
