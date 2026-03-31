#import <UIKit/UIKit.h>
#import <Security/Security.h>

// ────────────────────────────────────────────────────────
//  XXTExplorer Havoc Auth Patcher
//  Cài qua TrollStore → mở app → nhấn "Patch Now"
//  App sẽ ghi fake token/secret vào Keychain của XXTExplorer
//  và set NSUserDefaults để bypass authentication offline.
//
//  Bundle ID XXTExplorer : ch.xxtou.XXTExplorer
//  Keychain access group  : GXZ23M5TP2.ch.xxtou.XXTExplorer
//  Keychain service key   : KeychainHelper.[ch.xxtou.XXTExplorer]
// ────────────────────────────────────────────────────────

#define XXTEXPLORER_BUNDLE_ID   @"ch.xxtou.XXTExplorer"
#define XXTEXPLORER_TEAM        @"GXZ23M5TP2"
#define KC_ACCESS_GROUP         @"GXZ23M5TP2.ch.xxtou.XXTExplorer"
#define KC_SERVICE_BASE         @"KeychainHelper.[ch.xxtou.XXTExplorer]"
#define FAKE_TOKEN              @"bypass_token_offline_mode_xxt"
#define FAKE_SECRET             @"bypass_secret_offline_mode_xxt"

// ──────────────────────────────────────────
// MARK: - Keychain Helper Functions
// ──────────────────────────────────────────

static OSStatus writeKeychainItem(NSString *service, NSString *account, NSString *value) {
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    // Xoá item cũ trước
    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:     service,
        (__bridge id)kSecAttrAccount:     account,
        (__bridge id)kSecAttrAccessGroup: KC_ACCESS_GROUP,
    };
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    
    // Thêm item mới
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass:                   (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:             service,
        (__bridge id)kSecAttrAccount:             account,
        (__bridge id)kSecAttrAccessGroup:         KC_ACCESS_GROUP,
        (__bridge id)kSecAttrAccessible:          (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable:      (__bridge id)kCFBooleanFalse,
        (__bridge id)kSecValueData:               valueData,
    };
    return SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
}

static NSString *readKeychainItem(NSString *service, NSString *account) {
    NSDictionary *query = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:     service,
        (__bridge id)kSecAttrAccount:     account,
        (__bridge id)kSecAttrAccessGroup: KC_ACCESS_GROUP,
        (__bridge id)kSecReturnData:      (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit:      (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef dataRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataRef);
    if (status == errSecSuccess && dataRef) {
        NSData *data = (__bridge_transfer NSData *)dataRef;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

// ──────────────────────────────────────────
// MARK: - Patch Logic
// ──────────────────────────────────────────

static NSDictionary *performPatch(void) {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    // 1. Ghi token vào Keychain
    NSString *tokenService = [KC_SERVICE_BASE stringByAppendingString:@".token"];
    OSStatus tokenStatus = writeKeychainItem(tokenService, XXTEXPLORER_BUNDLE_ID, FAKE_TOKEN);
    results[@"keychain_token"] = (tokenStatus == errSecSuccess) ? @"✅ OK" 
        : [NSString stringWithFormat:@"❌ err=%d", (int)tokenStatus];
    
    // 2. Ghi secret vào Keychain
    NSString *secretService = [KC_SERVICE_BASE stringByAppendingString:@".secret"];
    OSStatus secretStatus = writeKeychainItem(secretService, XXTEXPLORER_BUNDLE_ID, FAKE_SECRET);
    results[@"keychain_secret"] = (secretStatus == errSecSuccess) ? @"✅ OK"
        : [NSString stringWithFormat:@"❌ err=%d", (int)secretStatus];
    
    // 3. Ghi updated_at vào Keychain
    NSString *updatedService = [KC_SERVICE_BASE stringByAppendingString:@".updated_at"];
    NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
    OSStatus tsStatus = writeKeychainItem(updatedService, XXTEXPLORER_BUNDLE_ID, timestamp);
    results[@"keychain_updated_at"] = (tsStatus == errSecSuccess) ? @"✅ OK"
        : [NSString stringWithFormat:@"❌ err=%d", (int)tsStatus];
    
    // 4. Verify đọc lại
    NSString *readToken = readKeychainItem(tokenService, XXTEXPLORER_BUNDLE_ID);
    results[@"verify_read"] = readToken ? @"✅ Readable" : @"⚠️ Cannot read back (cross-app OK)";
    
    // 5. Ghi NSUserDefaults shared (nếu app dùng suite)
    // XXTExplorer không dùng App Group nên dùng standard defaults không ảnh hưởng trực tiếp.
    // Nhưng ghi vào defaults của mình để log.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"bypass@offline.local" forKey:@"kXXTEMoreLicenseCachedEmail"];
    [defaults setObject:@"BYPASS-LICENSE-OFFLINE" forKey:@"kXXTEMoreLicenseCachedLicense"];
    [defaults setBool:YES forKey:@"XXTPatcherApplied"];
    [defaults synchronize];
    results[@"userdefaults"] = @"✅ Written (own container)";

    return results;
}

// ──────────────────────────────────────────
// MARK: - ViewController
// ──────────────────────────────────────────

@interface ViewController : UIViewController
@property (strong, nonatomic) UIButton *patchButton;
@property (strong, nonatomic) UITextView *logView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"XXTExplorer Auth Patcher";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Logo label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"🔓 XXTExplorer\nAuth Bypass Patcher";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"Ghi fake token/secret vào Keychain của\nXXTExplorer để chạy offline không cần auth";
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.numberOfLines = 0;
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:descLabel];
    
    // Patch button
    self.patchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.patchButton setTitle:@"  Patch Now  " forState:UIControlStateNormal];
    self.patchButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.patchButton.backgroundColor = [UIColor systemBlueColor];
    [self.patchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.patchButton.layer.cornerRadius = 14;
    self.patchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.patchButton addTarget:self action:@selector(patchTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.patchButton];
    
    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];
    
    // Log text view
    self.logView = [[UITextView alloc] init];
    self.logView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.layer.cornerRadius = 10;
    self.logView.editable = NO;
    self.logView.text = @"Log sẽ hiện ở đây sau khi patch...\n\n"
                         @"Target: ch.xxtou.XXTExplorer\n"
                         @"Access Group: GXZ23M5TP2.ch.xxtou.XXTExplorer\n";
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.logView];
    
    // ─── Constraints ───
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [descLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [descLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [descLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [descLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.patchButton.topAnchor constraintEqualToAnchor:descLabel.bottomAnchor constant:32],
        [self.patchButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.patchButton.widthAnchor constraintEqualToConstant:200],
        [self.patchButton.heightAnchor constraintEqualToConstant:52],
        
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.patchButton.bottomAnchor constant:16],
        
        [self.logView.topAnchor constraintEqualToAnchor:self.spinner.bottomAnchor constant:20],
        [self.logView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.logView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.logView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
    ]];
}

- (void)patchTapped {
    self.patchButton.enabled = NO;
    [self.spinner startAnimating];
    self.logView.text = @"Đang patch...\n";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *results = performPatch();
        
        NSMutableString *log = [NSMutableString string];
        [log appendString:@"=== Patch Results ===\n\n"];
        
        [log appendFormat:@"• Keychain Token:      %@\n", results[@"keychain_token"]];
        [log appendFormat:@"• Keychain Secret:     %@\n", results[@"keychain_secret"]];
        [log appendFormat:@"• Keychain updated_at: %@\n", results[@"keychain_updated_at"]];
        [log appendFormat:@"• Verify Read:         %@\n", results[@"verify_read"]];
        [log appendFormat:@"• NSUserDefaults:      %@\n\n", results[@"userdefaults"]];
        
        BOOL allOK = [results[@"keychain_token"] hasPrefix:@"✅"] &&
                     [results[@"keychain_secret"] hasPrefix:@"✅"];
        
        if (allOK) {
            [log appendString:@"✅ PATCH THÀNH CÔNG!\n\n"];
            [log appendString:@"→ Mở XXTExplorer, app sẽ đọc token từ\n  Keychain và không yêu cầu đăng nhập.\n\n"];
            [log appendString:@"⚠️ Lưu ý: Nếu Keychain của XXTExplorer\n"];
            [log appendString:@"  bị sandbox chặn cross-app, cần inject\n"];
            [log appendString:@"  dylib trực tiếp vào TIPA (xem README).\n"];
        } else {
            [log appendString:@"⚠️ Một số bước thất bại.\n\n"];
            [log appendString:@"Cross-app Keychain write có thể bị chặn.\n"];
            [log appendString:@"→ Dùng phương pháp inject dylib thay thế.\n"];
            [log appendString:@"→ Xem tweak/Tweak.x và build workflow.\n"];
        }
        
        [log appendFormat:@"\nBundle ID target: %@\n", XXTEXPLORER_BUNDLE_ID];
        [log appendFormat:@"Token: %@\n", FAKE_TOKEN];
        [log appendFormat:@"Secret: %@\n", FAKE_SECRET];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.patchButton.enabled = YES;
            [self.patchButton setTitle:@"  Patch Again  " forState:UIControlStateNormal];
            self.patchButton.backgroundColor = allOK ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];
            self.logView.text = log;
        });
    });
}

@end

// ──────────────────────────────────────────
// MARK: - AppDelegate
// ──────────────────────────────────────────

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[ViewController new]];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
