#import <UIKit/UIKit.h>

/*
 * Apps Manager Tweak - Diagnostic Version (Fixed Build Error)
 * This helps verify if the tweak is loaded and identifies the correct classes.
 */

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(void(^)(void))completion;
@end

@interface BackupInfoTableViewController : UITableViewController
- (void)updateNextBackupButtonWithTag:(NSString *)tag;
- (void)handleNextBackupTap;
- (void)handleNextBackupAction;
@end

@interface AppInfoTableViewController : UITableViewController
@property (nonatomic, retain) id item;
- (void)updateNextBackupButtonWithTag:(NSString *)tag;
- (void)handleNextBackupTap;
- (void)handleNextBackupAction;
@end

@interface BackupsTableViewController : UITableViewController
@property (nonatomic, retain) id app;
- (void)updateNextBackupButtonWithTag:(NSString *)tag;
- (void)handleNextBackupTap;
- (void)handleNextBackupAction;
@end

static NSMutableDictionary *appCurrentRunIndex;

// Shared Helper: Get identity for the app
static NSString *getAppId(id self) {
    id appObj = nil;
    if ([self respondsToSelector:@selector(app)]) appObj = [self performSelector:@selector(app)];
    if (!appObj && [self respondsToSelector:@selector(item)]) appObj = [self performSelector:@selector(item)];
    if (!appObj && [self respondsToSelector:@selector(backupInfo)]) {
        id info = [self performSelector:@selector(backupInfo)];
        if (info && [info respondsToSelector:@selector(app)]) appObj = [info performSelector:@selector(app)];
    }
    
    if (appObj && [appObj respondsToSelector:@selector(bundleIdentifier)]) {
        return [appObj performSelector:@selector(bundleIdentifier)];
    }
    return nil;
}

// Shared Helper: Update Button
static void applyButton(UIViewController *self, NSString *tag) {
    NSString *bundleId = getAppId(self);
    if (!bundleId || !self.navigationItem) return;

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger idx = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    
    NSString *title = [NSString stringWithFormat:@"%@ (Run:%ld)", tag, (long)idx];
    UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:title 
                                                            style:UIBarButtonItemStyleDone 
                                                           target:self 
                                                           action:@selector(handleNextBackupTap)];

    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray new];
    
    NSInteger existingIdx = -1;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIBarButtonItem *item = (UIBarButtonItem *)items[i];
        if (item && [item respondsToSelector:@selector(title)] && item.title && [item.title containsString:@"(Run:"]) {
            existingIdx = (NSInteger)i;
            break;
        }
    }

    if (existingIdx != -1) {
        [items replaceObjectAtIndex:(NSUInteger)existingIdx withObject:btn];
    } else {
        [items insertObject:btn atIndex:0];
    }
    self.navigationItem.rightBarButtonItems = items;
}

// Shared Helper: Handle button tap
static void handleButtonTap(UIViewController *self) {
    NSString *bundleId = getAppId(self);
    if (!bundleId) return;

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger currentIdx = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    [appCurrentRunIndex setObject:@(currentIdx + 1) forKey:bundleId];
    
    // Update display tag
    NSString *tag = @"Unknown";
    if ([self isKindOfClass:%c(BackupInfoTableViewController)]) tag = @"InfoList";
    else if ([self isKindOfClass:%c(AppInfoTableViewController)]) tag = @"AppInfo";
    else if ([self isKindOfClass:%c(BackupsTableViewController)]) tag = @"BackupList";

    if ([self respondsToSelector:@selector(updateNextBackupButtonWithTag:)]) {
        [self performSelector:@selector(updateNextBackupButtonWithTag:) withObject:tag];
    }
}

// Shared Helper: Sync index on row tap
static void syncIndex(UIViewController *self, NSIndexPath *indexPath) {
    NSString *bundleId = getAppId(self);
    if (!bundleId) return;

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    [appCurrentRunIndex setObject:@(indexPath.row) forKey:bundleId];

    NSString *tag = @"Unknown";
    if ([self isKindOfClass:%c(BackupInfoTableViewController)]) tag = @"InfoList";
    else if ([self isKindOfClass:%c(AppInfoTableViewController)]) tag = @"AppInfo";
    else if ([self isKindOfClass:%c(BackupsTableViewController)]) tag = @"BackupList";

    if ([self respondsToSelector:@selector(updateNextBackupButtonWithTag:)]) {
        [self performSelector:@selector(updateNextBackupButtonWithTag:) withObject:tag];
    }
}

// --- Hooks ---

%hook BackupInfoTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButtonWithTag:@"InfoList"]; }
%new - (void)updateNextBackupButtonWithTag:(NSString *)tag { applyButton(self, tag); }
%new - (void)handleNextBackupTap { [self handleNextBackupAction]; }
%new - (void)handleNextBackupAction { handleButtonTap(self); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    syncIndex(self, indexPath);
}
%end

%hook AppInfoTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButtonWithTag:@"AppInfo"]; }
%new - (void)updateNextBackupButtonWithTag:(NSString *)tag { applyButton(self, tag); }
%new - (void)handleNextBackupTap { [self handleNextBackupAction]; }
%new - (void)handleNextBackupAction { handleButtonTap(self); }
%end

%hook BackupsTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButtonWithTag:@"BackupList"]; }
%new - (void)updateNextBackupButtonWithTag:(NSString *)tag { applyButton(self, tag); }
%new - (void)handleNextBackupTap { [self handleNextBackupAction]; }
%new - (void)handleNextBackupAction { handleButtonTap(self); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    syncIndex(self, indexPath);
}
%end

// Global Diagnostic Alert
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AMBackupHelper" 
                                                                       message:@"Diagnostic Tweak Loaded!" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    window = windowScene.windows.firstObject; break;
                }
            }
        } else {
            window = [UIApplication sharedApplication].keyWindow;
        }
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
