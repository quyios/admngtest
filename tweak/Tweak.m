/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v11)
 *
 * PURCHASE RECORD BYPASS:
 * 1. Giả lập gói cước "XXTouch Elite TS" trong danh sách đã mua.
 * 2. Hook hasPurchasedPackageWithIdentifier để luôn trả về YES.
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

static char const *const kCompletionBlockKeyV11 = "kCompletionBlockKeyV11";

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
// MARK: - Fake Models
// ─────────────────────────────────────────

@interface XXTFakePackageV11 : NSObject @end
@implementation XXTFakePackageV11
- (NSString *)identifier { return kELITE_PACKAGE; }
- (NSString *)name       { return @"XXTouch Elite TS"; }
- (BOOL)isPurchased      { return YES; }
@end

@interface XXTFakeAccountV11 : NSObject @end
@implementation XXTFakeAccountV11
- (BOOL)isValid            { return YES; }
- (BOOL)isAuthenticated    { return YES; }
- (BOOL)isRegistered       { return YES; }
- (BOOL)isAuthorized       { return YES; }
- (NSString *)token        { return kBYPASS_TOKEN; }
- (NSString *)secret       { return kBYPASS_SECRET; }
- (NSString *)email        { return @"bypass@offline.local"; }
- (NSArray *)purchasedPackages { return @[[XXTFakePackageV11 new]]; }
- (BOOL)hasPurchasedPackageWithIdentifier:(NSString *)ident { return YES; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

// ─────────────────────────────────────────
// MARK: - Hook Categories
// ─────────────────────────────────────────

@interface UILabel (BypassV11) @end
@implementation UILabel (BypassV11)
- (void)bp_v11_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) {
            text = @"Registered";
        } else if ([text containsString:@"Unauthorized device"]) {
            text = @"Elite License Active (TS)";
        }
    }
    [self bp_v11_setText:text];
}
@end

@interface UIViewController (BypassV11) @end
@implementation UIViewController (BypassV11)
- (NSString *)bp_v11_tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    NSString *orig = [self bp_v11_tableView:tv titleForFooterInSection:s];
    if ([orig containsString:@"Unauthorized device"]) {
        return @"XXTouch Elite Bypassed via TrollStore.";
    }
    return orig;
}
@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV11Bypass(void) {
    // 1. UI Hooks
    swizzle([UILabel class], @selector(setText:), @selector(bp_v11_setText:));
    
    Class LC = NSClassFromString(@"XXTEMoreLicenseController");
    if (LC) {
        swizzle(LC, @selector(tableView:titleForFooterInSection:), @selector(bp_v11_tableView:titleForFooterInSection:));
        class_replaceMethod(LC, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(LC, @selector(isRegistered), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }

    // 2. ASWebAuth / SFAuth Bypass
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    for (NSString *name in @[@"ASWebAuthenticationSession", @"SFAuthenticationSession"]) {
        Class cls = NSClassFromString(name);
        if (cls) {
            class_replaceMethod(cls, @selector(initWithURL:callbackURLScheme:completionHandler:), imp_implementationWithBlock(^id(id self, NSURL *url, NSString *scheme, id cb){
                 objc_setAssociatedObject(self, kCompletionBlockKeyV11, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
                 return self; 
            }), "@@:@@@");
            
            class_replaceMethod(cls, @selector(start), imp_implementationWithBlock(^BOOL(id self){
                void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV11);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL URLWithString:kSUCCESS_URL], nil); });
                }
                return YES;
            }), "B@:");
        }
    }

    // 3. HVCHavocAccount & HVCKeychainHelper
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        XXTFakeAccountV11 *fake = [XXTFakeAccountV11 new];
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        class_replaceMethod(object_getClass(HA), @selector(account), imp_implementationWithBlock(^id(id self){ return fake; }), "@@:");
        
        // Brute Force BOOL Hooks for Account
        class_replaceMethod(HA, @selector(isValid), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isAuthenticated), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        class_replaceMethod(HA, @selector(isAuthorized), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
        
        // Hook purchasedPackages
        class_replaceMethod(HA, @selector(purchasedPackages), imp_implementationWithBlock(^NSArray*(id self){ return @[[XXTFakePackageV11 new]]; }), "@@:");
        class_replaceMethod(HA, @selector(hasPurchasedPackageWithIdentifier:), imp_implementationWithBlock(^BOOL(id self, NSString *ident){ return YES; }), "B@:@");
    }

    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        class_replaceMethod(KC, @selector(token), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(KC, @selector(secret), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_SECRET; }), "@@:");
        class_replaceMethod(object_getClass(KC), @selector(accountExists), imp_implementationWithBlock(^BOOL(id self){ return YES; }), "B@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d synchronize];
        applyV11Bypass();
    }
}
