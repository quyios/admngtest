/*
 * XXTExplorer Havoc Auth Bypass - TrollStore Edition (v8)
 *
 * BRUTE FORCE BYPASS:
 * 1. Duyệt toàn bộ Class trong app, hook bất kỳ hàm nào tên là isRegistered/isAuthorized...
 * 2. Hook UILabel setText để ép hiển thị chữ "Registered".
 * 3. Ép Token thật của bạn vào mọi nơi.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// ─────────────────────────────────────────
// MARK: - Constants & Tokens
// ─────────────────────────────────────────

static NSString *const kBYPASS_TOKEN  = @"e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6";
static NSString *const kBYPASS_SECRET = @"f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";
static NSString *const kSUCCESS_URL   = @"sileo://authentication_success?token=e3691a72c623d050e5506c8128e0fc3e37e6e2836dc40bc5ee7eb568edaba7a6&payment_secret=f66651c3893125261d07168d702d5c136afb82a2bf0bfeb99090dc42f3a00b6d";

static char const *const kCompletionBlockKey = "kCompletionBlockKeyV8";

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
// MARK: - Brute Force Helper
// ─────────────────────────────────────────

static BOOL shouldForceTrue(NSString *selName) {
    NSArray *targets = @[@"isAuthorized", @"isRegistered", @"isAuthenticated", @"isActivated", @"isValid", @"isVerified", @"accountExists"];
    for (NSString *t in targets) {
        if ([selName isEqualToString:t]) return YES;
    }
    return NO;
}

static BOOL forced_BOOL(id self, SEL _cmd) { return YES; }
static id forced_ID(id self, SEL _cmd) { return @[[NSObject new]]; }

// ─────────────────────────────────────────
// MARK: - UI Hooks
// ─────────────────────────────────────────

@interface UILabel (BypassV8) @end
@implementation UILabel (BypassV8)
- (void)bp_v8_setText:(NSString *)text {
    if ([text containsString:@"Not Registered"]) {
        [self bp_v8_setText:@"Registered"];
        return;
    }
    if ([text containsString:@"Unauthorized device"]) {
        [self bp_v8_setText:@""]; // Xoá dòng cảnh báo
        return;
    }
    [self bp_v8_setText:text];
}
@end

// ─────────────────────────────────────────
// MARK: - System Hooks
// ─────────────────────────────────────────

@interface XXTBypassHooksV8 : NSObject @end
@implementation XXTBypassHooksV8

// Account Singleton
+ (id)bp_shared { return self; }
- (BOOL)isTrue    { return YES; }
- (id)bp_token    { return kBYPASS_TOKEN; }
- (id)bp_secret   { return kBYPASS_SECRET; }
- (id)bp_email    { return @"bypass@offline.local"; }
- (id)bp_username { return @"BypassUser"; }
- (id)bp_viewers  { return @[[NSObject new]]; }

// ASWebAuth Capture
- (id)bp_initWithURL:(NSURL *)url callbackURLScheme:(id)s completionHandler:(void(^)(id,id))cb {
    id instance = [self bp_initWithURL:url callbackURLScheme:s completionHandler:cb];
    if (instance && cb) {
        objc_setAssociatedObject(instance, kCompletionBlockKey, cb, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return instance;
}

- (BOOL)bp_start {
    void (^completion)(NSURL *, NSError *) = objc_getAssociatedObject(self, kCompletionBlockKey);
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:kSUCCESS_URL], nil);
        });
        return YES;
    }
    return [self bp_start];
}

@end

// ─────────────────────────────────────────
// MARK: - Main Apply
// ─────────────────────────────────────────

static void applyV8Bypass(void) {
    // 1. Hook UILabel để sửa UI trực quan
    swizzle([UILabel class], @selector(setText:), @selector(bp_v8_setText:));

    // 2. Hook ASWebAuthenticationSession
    dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_NOW);
    Class AS = NSClassFromString(@"ASWebAuthenticationSession");
    if (AS) {
        swizzle(AS, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(bp_initWithURL:callbackURLScheme:completionHandler:));
        swizzle(AS, @selector(start), @selector(bp_start));
    }

    // 3. Brute Force Hook - Tìm và diệt các hàm check license
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *clsName = NSStringFromClass(cls);
            
            // Chỉ hook các class của app hoặc Havoc
            if ([clsName hasPrefix:@"XXTE"] || [clsName hasPrefix:@"HVC"]) {
                // Hook các hàm BOOL trả về YES
                unsigned int mc = 0;
                Method *mlist = class_copyMethodList(cls, &mc);
                for (unsigned int m = 0; m < mc; m++) {
                    SEL sel = method_getName(mlist[m]);
                    NSString *selName = NSStringFromSelector(sel);
                    if (shouldForceTrue(selName)) {
                        class_replaceMethod(cls, sel, (IMP)forced_BOOL, "B@:");
                    }
                }
                free(mlist);
                
                // Hook các hàm singleton cơ bản (sharedInstance, currentAccount...)
                if (class_getClassMethod(cls, @selector(currentAccount))) {
                    class_replaceMethod(object_getClass(cls), @selector(currentAccount), (IMP)forced_ID, "@@:");
                }
                if (class_getClassMethod(cls, @selector(sharedInstance))) {
                     class_replaceMethod(object_getClass(cls), @selector(sharedInstance), (IMP)forced_ID, "@@:");
                }
            }
        }
        free(classes);
    }
    
    // 4. Hook Token cụ thể cho HVCKeychainHelper
    Class KC = NSClassFromString(@"HVCKeychainHelper");
    if (KC) {
        swizzle(KC, @selector(token), @selector(bp_token));
        swizzle(KC, @selector(secret), @selector(bp_secret));
    }
}

__attribute__((constructor))
static void dylib_init(void) {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        [d setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        [d synchronize];
        
        applyV8Bypass();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            applyV8Bypass();
        }];
    }
}
