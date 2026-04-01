/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v9)
 *
 * SAFE UI BYPASS - Sửa lỗi crash v8. 
 * Điều chỉnh: 
 *   - Hook UILabel an toàn hơn.
 *   - Giới hạn Brute Force chỉ trên các class XXTE và HVC.
 *   - Đảm bảo token thật luôn được trả về.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// ─────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN  = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL   = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";

static char const *const kCompletionBlockKeyV9 = "kCompletionBlockKeyV9";

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
// MARK: - Fake Account (Safe Implementation)
// ─────────────────────────────────────────

@interface XXTFakeAccountV9 : NSObject @end
@implementation XXTFakeAccountV9
- (BOOL)isValid         { return YES; }
- (BOOL)isAuthenticated { return YES; }
- (BOOL)isRegistered    { return YES; }
- (BOOL)isAuthorized    { return YES; }
- (NSString *)token     { return kBYPASS_TOKEN; }
- (NSString *)secret    { return kBYPASS_SECRET; }
- (NSString *)email     { return @"bypass@offline.local"; }
- (NSArray *)registeredViewers { return @[[NSObject new]]; }
@end

// ─────────────────────────────────────────
// MARK: - Hook Class Implementations
// ─────────────────────────────────────────

@interface XXTUIHooksV9 : NSObject @end
@implementation XXTUIHooksV9

// UILabel setText Hook
- (void)bp_v9_setText:(NSString *)text {
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"Not Registered"]) {
            [self bp_v9_setText:@"Registered"];
            return;
        }
        if ([text containsString:@"Unauthorized device"]) {
            [self bp_v9_setText:@""]; // Hide notice
            return;
        }
    }
    [self bp_v9_setText:text];
}

// ASWebAuth Capture
- (id)bp_v9_initWithURL:(NSURL *)url callbackURLScheme:(id)s completionHandler:(id)cb {
    id instance = [self bp_v9_initWithURL:url callbackURLScheme:s completionHandler:cb];
    if (instance && cb) {
        objc_setAssociatedObject(instance, kCompletionBlockKeyV9, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return instance;
}

- (BOOL)bp_v9_start {
    void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKeyV9);
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:kSUCCESS_URL], nil);
        });
        return YES;
    }
    return [self bp_v9_start];
}

@end

// ─────────────────────────────────────────
// MARK: - Brute Force Functions
// ─────────────────────────────────────────

static BOOL forced_BOOL_YES(id self, SEL _cmd) { return YES; }

static void applyV9Bypass(void) {
    // 1. Hook UILabel
    swizzle([UILabel class], @selector(setText:), @selector(bp_v9_setText:));

    // 2. Hook ASWebAuth
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        swizzle(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_v9_initWithURL:callbackURLScheme:completionHandler:));
        swizzle(AS, @selector(start), @selector(bp_v9_start));
    }

    // 3. Selective Brute Force
    NSArray *boolMethods = @[@"isAuthorized", @"isRegistered", @"isAuthenticated", @"isValid", @"isActivated", @"accountExists"];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *clsName = NSStringFromClass(cls);
            if ([clsName hasPrefix:@"XXTE"] || [clsName hasPrefix:@"HVC"]) {
                for (NSString *selStr in boolMethods) {
                    SEL sel = NSSelectorFromString(selStr);
                    Method m = class_getInstanceMethod(cls, sel);
                    if (m) {
                        // Chỉ thay đổi nếu signature là BOOL, NO params (B@:)
                        const char *type = method_getTypeEncoding(m);
                        if (type && strcmp(type, "B@:") == 0) {
                            class_replaceMethod(cls, sel, (IMP)forced_BOOL_YES, type);
                        }
                    }
                }
                
                // Singleton hooks
                SEL selCur = @selector(currentAccount);
                if (class_getClassMethod(cls, selCur)) {
                    class_replaceMethod(object_getClass(cls), selCur, (IMP)forced_BOOL_YES, "@@:"); // Return self as fake or similar
                }
            }
        }
        free(classes);
    }
    
    // 4. Specific Token Fix
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        // Trình duyệt text để trả về token thật
        class_replaceMethod(KC, @selector(token), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_TOKEN; }), "@@:");
        class_replaceMethod(KC, @selector(secret), imp_implementationWithBlock(^NSString*(id self){ return kBYPASS_SECRET; }), "@@:");
        class_replaceMethod(object_getClass(KC), @selector(accountExists), (IMP)forced_BOOL_YES, "B@:");
    }
    
    Class HA = NSClassFromString(@"HVCHavocAccount");
    if (HA) {
        class_replaceMethod(object_getClass(HA), @selector(currentAccount), imp_implementationWithBlock(^id(id self){ return [XXTFakeAccountV9 new]; }), "@@:");
        class_replaceMethod(object_getClass(HA), @selector(account), imp_implementationWithBlock(^id(id self){ return [XXTFakeAccountV9 new]; }), "@@:");
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];
        
        applyV9Bypass();
    }
}
