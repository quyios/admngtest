#import <UIKit/UIKit.h>

/*
 * Apps Manager Tweak - Backup Sorting & Sequential Restoration
 */

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(void(^)(void))completion;
@end

@interface AppInfoTableViewController : UITableViewController
@property (nonatomic, retain) id item; // Usually the app object
- (id)backupInfo; // Potentially contains the backup list
- (void)updateNextBackupButton;
- (NSString *)getBundleIdSafely;
- (void)handleNextBackupTap;
@end

// Global track for current index per app
static NSMutableDictionary *appCurrentRunIndex;

%hook AppInfoTableViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self updateNextBackupButton];
}

%new
- (void)updateNextBackupButton {
    if (!self.navigationItem) return;

    NSString *bundleId = [self getBundleIdSafely];
    NSInteger idx = 0;
    if (bundleId && appCurrentRunIndex) {
        idx = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    }

    NSString *title = [NSString stringWithFormat:@"Next (Run:%ld)", (long)idx];
    
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:title 
                                                                   style:UIBarButtonItemStyleDone 
                                                                  target:self 
                                                                  action:@selector(handleNextBackupTap)];
    
    // Replace or add the button
    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!items) items = [NSMutableArray new];
    
    NSInteger existingIdx = -1;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIBarButtonItem *item = items[i];
        if ([item.title containsString:@"Next (Run:"]) {
            existingIdx = (NSInteger)i;
            break;
        }
    }
    
    if (existingIdx != -1) {
        [items replaceObjectAtIndex:(NSUInteger)existingIdx withObject:nextButton];
    } else {
        [items addObject:nextButton];
    }
    self.navigationItem.rightBarButtonItems = items;
}

%new
- (NSString *)getBundleIdSafely {
    id appObj = nil;
    if ([self respondsToSelector:@selector(item)]) appObj = [self performSelector:@selector(item)];
    if (!appObj && [self respondsToSelector:@selector(backupInfo)]) {
        id info = [self performSelector:@selector(backupInfo)];
        if (info && [info respondsToSelector:@selector(app)]) appObj = [info performSelector:@selector(app)];
    }
    if (appObj && [appObj respondsToSelector:@selector(bundleIdentifier)]) {
        return [appObj performSelector:@selector(bundleIdentifier)];
    }
    return nil;
}

%new
- (void)handleNextBackupTap {
    NSString *bundleId = [self getBundleIdSafely];
    if (!bundleId) return;

    id appObj = nil;
    if ([self respondsToSelector:@selector(item)]) appObj = [self performSelector:@selector(item)];
    if (!appObj) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:appObj];
    if (![backups isKindOfClass:[NSArray class]] || backups.count == 0) return;

    // Use a consistent sorting (Ascending by date for sequential)
    NSArray *sortedBackups = [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        NSDate *d1 = [b1 valueForKey:@"fileDate"];
        NSDate *d2 = [b2 valueForKey:@"fileDate"];
        return [d1 compare:d2];
    }];

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger currentIndex = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    
    if (currentIndex >= sortedBackups.count) currentIndex = 0;

    id targetBackup = sortedBackups[currentIndex];
    NSString *path = [targetBackup valueForKey:@"path"] ?: [targetBackup valueForKey:@"filePath"];
    
    if (!path) return;

    [[%c(BackupList) sharedInstance] restoreApp:appObj fromPathBackup:path progress:nil withCompletion:^{
        // Increment for next run
        NSInteger nextIndex = (currentIndex + 1) % sortedBackups.count;
        [appCurrentRunIndex setObject:@(nextIndex) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateNextBackupButton];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restored" 
                                                                           message:[NSString stringWithFormat:@"Finished Run %ld", (long)currentIndex] 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

// Intercept manual selection to set the "starting" index
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;

    NSString *bundleId = [self getBundleIdSafely];
    if (!bundleId) return;

    id appObj = [self respondsToSelector:@selector(item)] ? [self performSelector:@selector(item)] : nil;
    if (!appObj) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:appObj];
    if (![backups isKindOfClass:[NSArray class]] || backups.count == 0) return;

    // Mapping logic: The list in UI is sorted Newest First (Descending).
    // Our "Run" count is Ascending (Oldest First).
    // If the list has N items:
    // UI index 0 (Newest) = Ascending index N-1
    // UI index k = Ascending index (N - 1 - k)
    
    // We assume backups are in section 0 or 1. Usually ADManager uses section 0 or 1.
    // Based on the screenshot, it's likely section 0.
    NSInteger totalBackups = (NSInteger)backups.count;
    NSInteger tappedRow = indexPath.row;
    
    if (tappedRow < totalBackups) {
        NSInteger ascendingIdx = totalBackups - 1 - tappedRow;
        if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
        [appCurrentRunIndex setObject:@(ascendingIdx) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateNextBackupButton];
        });
    }
}

%end

// Force sort in the data layer for better UX
%hook BackupList
- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    if (![backups isKindOfClass:[NSArray class]] || backups.count < 2) return backups;
    return [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        return [[b2 valueForKey:@"fileDate"] compare:[b1 valueForKey:@"fileDate"]]; // Newest first for UI
    }];
}
%end
