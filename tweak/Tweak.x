/*
 * XXTExplorer Havoc Auth Bypass Dylib
 *
 * Hooks tất cả authentication/license checks để trả về trạng thái đã xác thực.
 * Targets:
 *   - HVCKeychainHelper  — đọc token/secret từ Keychain
 *   - HVCHavocAccount    — kiểm tra trạng thái tài khoản
 *   - HVCHavocSecret     — xác minh secret
 *   - XXTEMoreLicenseController — UI license check
 *   - NSURLSession hooks — block DRM server calls (drm.82flex.com)
 *   - NSURLConnection hooks — block older-style network calls
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────
// MARK: - HVCKeychainHelper
// Lớp này quản lý đọc/ghi token + secret vào Keychain iOS
// Trả về token/secret fake (không rỗng) để app coi như đã login
// ─────────────────────────────────────────
%hook HVCKeychainHelper

// Kiểm tra xem account có tồn tại không → YES
+ (BOOL)accountExists {
    return YES;
}
- (BOOL)accountExists {
    return YES;
}

// Trả token giả — đủ để pass các kiểm tra non-null
+ (NSString *)tokenForKey:(NSString *)key {
    return @"bypass_token_offline_mode_xxt";
}
- (NSString *)tokenForKey:(NSString *)key {
    return @"bypass_token_offline_mode_xxt";
}

// Trả secret giả
+ (NSString *)secretForKey:(NSString *)key {
    return @"bypass_secret_offline_mode_xxt";
}
- (NSString *)secretForKey:(NSString *)key {
    return @"bypass_secret_offline_mode_xxt";
}

// Nếu app đọc token bằng getter trực tiếp
- (NSString *)token {
    return @"bypass_token_offline_mode_xxt";
}
- (NSString *)secret {
    return @"bypass_secret_offline_mode_xxt";
}

// loadAccount trả về self (object hợp lệ)
- (id)loadAccountWithCompletion:(void (^)(id account, NSError *error))completion {
    if (completion) {
        // Tạo đối tượng account giả thông qua runtime để tránh crash
        id fakeAccount = [NSObject new];
        completion(fakeAccount, nil);
    }
    return self;
}

// removeAccount — không làm gì (giữ trạng thái bypass)
- (void)removeAccountFromKeychain:(NSString *)key completion:(void (^)(BOOL success))completion {
    if (completion) completion(YES);
}

// Lưu account — không làm gì thực, callback success
- (void)saveAccountWithToken:(NSString *)token secret:(NSString *)secret completion:(void (^)(BOOL success, NSError *error))completion {
    if (completion) completion(YES, nil);
}

%end


// ─────────────────────────────────────────
// MARK: - HVCHavocAccount
// Object đại diện cho tài khoản Havoc
// ─────────────────────────────────────────
%hook HVCHavocAccount

// Khởi tạo với token + secret giả
- (instancetype)initWithEndpoint:(id)endpoint token:(NSString *)token secret:(NSString *)secret {
    self = %orig(endpoint, @"bypass_token_offline_mode_xxt", @"bypass_secret_offline_mode_xxt");
    return self;
}

- (NSString *)token {
    return @"bypass_token_offline_mode_xxt";
}

- (NSString *)secret {
    return @"bypass_secret_offline_mode_xxt";
}

// Nếu có isValid / isAuthenticated property
- (BOOL)isValid {
    return YES;
}

- (BOOL)isAuthenticated {
    return YES;
}

%end


// ─────────────────────────────────────────
// MARK: - HVCHavocSecret
// Object xác minh secret/payment từ Havoc
// ─────────────────────────────────────────
%hook HVCHavocSecret

- (BOOL)isValid {
    return YES;
}

- (BOOL)isVerified {
    return YES;
}

- (NSString *)secret {
    return @"bypass_secret_offline_mode_xxt";
}

%end


// ─────────────────────────────────────────
// MARK: - HVCHavocConfiguration
// Config chứa endpoint và UDID
// ─────────────────────────────────────────
%hook HVCHavocConfiguration

// Tránh crash khi app dùng config
- (BOOL)isValid {
    return YES;
}

%end


// ─────────────────────────────────────────
// MARK: - XXTEMoreLicenseController
// Controller hiển thị UI License, check và present alert "Purchase Required"
// ─────────────────────────────────────────
%hook XXTEMoreLicenseController

// Không hiện alert "Purchase Required"
- (void)presentPurchaseAlert {
    // no-op: bỏ qua hoàn toàn
}

// Không redirect sang trang mua hàng
- (void)redirectToPurchasePage {
    // no-op
}

- (void)redirectToMyPurchasesPage {
    // no-op
}

// Update license dictionary — không làm gì để tránh overwrite state
- (void)updateLicenseDictionary:(id)dict {
    // no-op
}

%end


// ─────────────────────────────────────────
// MARK: - NSURLSession Block DRM + Havoc
// Block tất cả request đến drm.82flex.com và havoc.app
// Trả về response 200 OK với JSON {"status":"ok","valid":true}
// ─────────────────────────────────────────

static BOOL isBypassed(NSString *host) {
    if (!host) return NO;
    return ([host containsString:@"drm.82flex.com"] ||
            [host containsString:@"havoc.app"]);
}

static NSData *fakeOKResponse() {
    NSDictionary *d = @{@"status": @"ok", @"valid": @YES, @"authenticated": @YES};
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *host = request.URL.host;
    if (isBypassed(host)) {
        if (completionHandler) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
                initWithURL:request.URL
                 statusCode:200
                HTTPVersion:@"HTTP/1.1"
               headerFields:@{@"Content-Type": @"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(fakeOKResponse(), resp, nil);
            });
        }
        // Trả dummy task (không chạy)
        return %orig([NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]], completionHandler);
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSString *host = url.host;
    if (isBypassed(host)) {
        if (completionHandler) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
                initWithURL:url
                 statusCode:200
                HTTPVersion:@"HTTP/1.1"
               headerFields:@{@"Content-Type": @"application/json"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(fakeOKResponse(), resp, nil);
            });
        }
        return %orig([NSURL URLWithString:@"about:blank"], completionHandler);
    }
    return %orig;
}

%end


// ─────────────────────────────────────────
// MARK: - NSURLConnection Block (older API)
// ─────────────────────────────────────────
%hook NSURLConnection

+ (void)sendAsynchronousRequest:(NSURLRequest *)request
                           queue:(NSOperationQueue *)queue
               completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    NSString *host = request.URL.host;
    if (isBypassed(host)) {
        if (handler) {
            NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
                initWithURL:request.URL
                 statusCode:200
                HTTPVersion:@"HTTP/1.1"
               headerFields:@{@"Content-Type": @"application/json"}];
            [queue addOperationWithBlock:^{
                handler(resp, fakeOKResponse(), nil);
            }];
        }
        return;
    }
    %orig;
}

%end


// ─────────────────────────────────────────
// MARK: - Constructor: Pre-populate NSUserDefaults
// Set cache email/license vào NSUserDefaults ngay khi dylib load
// để app không hiện màn hình chưa đăng nhập
// ─────────────────────────────────────────
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        // Chỉ set nếu chưa có giá trị (tránh ghi đè dữ liệu thật nếu user đã auth)
        if (![defaults objectForKey:@"kXXTEMoreLicenseCachedEmail"]) {
            [defaults setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
        }
        if (![defaults objectForKey:@"kXXTEMoreLicenseCachedLicense"]) {
            [defaults setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
        }
        [defaults synchronize];
    }
}
