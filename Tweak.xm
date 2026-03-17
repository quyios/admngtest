#import <UIKit/UIKit.h>

/*
 * Apps Manager Tweak - Backup Sorting & Sequential Restoration
 * Fixed: Type casting error and dual-controller support
 */

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(void(^)(void))completion;
@end

@interface BackupInfoTableViewController : UITableViewController
- (id)backupInfo;
- (void)updateNextBackupButton;
- (void)handleNextBackupTap;
@end

@interface AppInfoTableViewController : UITableViewController
@property (nonatomic, retain) id item;
- (void)updateNextBackupButton;
- (void)handleNextBackupTap;
@end

@interface BackupsTableViewController : UITableViewController
@property (nonatomic, retain) id app;
- (void)updateNextBackupButton;
- (void)handleNextBackupTap;
@end

static NSMutableDictionary *appCurrentRunIndex;

// Shared Helper: Get App Object
static id getAppObjectFromController(UIViewController *ctrl) {
    if ([ctrl respondsToSelector:@selector(app)]) return [ctrl performSelector:@selector(app)];
    if ([ctrl respondsToSelector:@selector(item)]) return [ctrl performSelector:@selector(item)];
    if ([ctrl respondsToSelector:@selector(backupInfo)]) {
        id info = [ctrl performSelector:@selector(backupInfo)];
        if (info && [info respondsToSelector:@selector(app)]) return [info performSelector:@selector(app)];
    }
    return nil;
}

// Shared Helper: Get Bundle ID
static NSString *getBundleIdFromController(UIViewController *ctrl) {
    id app = getAppObjectFromController(ctrl);
    if (app && [app respondsToSelector:@selector(bundleIdentifier)]) {
        return [app performSelector:@selector(bundleIdentifier)];
    }
    return nil;
}

// Shared Helper: Update Button Title
static void updateButtonDisplay(UIViewController *self) {
    NSString *bid = getBundleIdFromController(self);
    if (!bid) return;

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger idx = [[appCurrentRunIndex objectForKey:bid] integerValue];
    
    NSString *title = [NSString stringWithFormat:@"Next(Run:%ld)", (long)idx];
    UIBarButtonItem *nextBtn = [[UIBarButtonItem alloc] initWithTitle:title 
                                                               style:UIBarButtonItemStyleDone 
                                                              target:self 
                                                              action:@selector(handleNextBackupTap)];

    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray new];
    
    NSInteger existingIdx = -1;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIBarButtonItem *item = (UIBarButtonItem *)items[i];
        // Safe check for title property
        if (item && [item respondsToSelector:@selector(title)] && item.title && [item.title containsString:@"Next(Run:"]) {
            existingIdx = (NSInteger)i;
            break;
        }
    }

    if (existingIdx != -1) {
        [items replaceObjectAtIndex:(NSUInteger)existingIdx withObject:nextBtn];
    } else {
        [items insertObject:nextBtn atIndex:0]; // Insert at start to not hide Edit button
    }
    
    self.navigationItem.rightBarButtonItems = items;
}

// Shared Helper: Handle Tap
static void handleButtonTap(UIViewController *self) {
    id app = getAppObjectFromController(self);
    NSString *bundleId = getBundleIdFromController(self);
    if (!app || !bundleId) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:app];
    if (![backups isKindOfClass:[NSArray class]] || backups.count == 0) return;

    // Ascending sort for sequential run (Oldest -> Newest)
    NSArray *sorted = [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        NSDate *d1 = [b1 valueForKey:@"fileDate"];
        NSDate *d2 = [b2 valueForKey:@"fileDate"];
        return [d1 compare:d2];
    }];

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger currentIdx = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    if (currentIdx >= sorted.count) currentIdx = 0;

    id targetBackup = sorted[currentIdx];
    NSString *path = [targetBackup valueForKey:@"path"] ?: [targetBackup valueForKey:@"filePath"];
    if (!path) return;

    [[%c(BackupList) sharedInstance] restoreApp:app fromPathBackup:path progress:nil withCompletion:^{
        // Increment and wrap around
        NSInteger nextIdx = (currentIdx + 1) % sorted.count;
        [appCurrentRunIndex setObject:@(nextIdx) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self respondsToSelector:@selector(updateNextBackupButton)]) {
                [self performSelector:@selector(updateNextBackupButton)];
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restored" 
                                                                           message:[NSString stringWithFormat:@"Finished Run %ld", (long)currentIdx] 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

// Shared Helper: Sync index on row tap
static void syncIndexOnTap(id self, NSIndexPath *indexPath) {
    NSString *bid = getBundleIdFromController(self);
    id app = getAppObjectFromController(self);
    if (!bid || !app) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:app];
    if ([backups isKindOfClass:[NSArray class]] && backups.count > 0) {
        NSInteger total = (NSInteger)backups.count;
        if (indexPath.row < total) {
            // UI is sorted Newest First (Descending)
            // Run index is Ascending (0 = Oldest)
            NSInteger ascendingIdx = total - 1 - indexPath.row;
            if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
            [appCurrentRunIndex setObject:@(ascendingIdx) forKey:bid];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self respondsToSelector:@selector(updateNextBackupButton)]) {
                    [self performSelector:@selector(updateNextBackupButton)];
                }
            });
        }
    }
}

// Hook everywhere backups might appear
%hook BackupInfoTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButton]; }
%new - (void)updateNextBackupButton { updateButtonDisplay(self); }
%new - (void)handleNextBackupTap { handleButtonTap(self); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    syncIndexOnTap(self, indexPath);
}
%end

%hook AppInfoTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButton]; }
%new - (void)updateNextBackupButton { updateButtonDisplay(self); }
%new - (void)handleNextBackupTap { handleButtonTap(self); }
%end

%hook BackupsTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButton]; }
%new - (void)updateNextBackupButton { updateButtonDisplay(self); }
%new - (void)handleNextBackupTap { handleButtonTap(self); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    syncIndexOnTap(self, indexPath);
}
%end

// Global Sort Hook
%hook BackupList
- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    if (![backups isKindOfClass:[NSArray class]] || backups.count < 2) return backups;
    return [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        return [[b2 valueForKey:@"fileDate"] compare:[b1 valueForKey:@"fileDate"]]; // UI shows newest at top
    }];
}
%end
