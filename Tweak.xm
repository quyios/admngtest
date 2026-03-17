#import <UIKit/UIKit.h>

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(void(^)(void))completion;
@end

@interface BackupsTableViewController : UITableViewController
@property (nonatomic, retain) id app; // ivar _app
- (void)updateNextBackupButton;
@end

@interface AppInfoTableViewController : UITableViewController
@property (nonatomic, retain) id item;
- (void)updateNextBackupButton;
@end

static NSMutableDictionary *appCurrentRunIndex;

// Shared Logic for both controllers
static NSString *getBundleId(id controller) {
    id appObj = nil;
    if ([controller respondsToSelector:@selector(app)]) appObj = [controller performSelector:@selector(app)];
    if (!appObj && [controller respondsToSelector:@selector(item)]) appObj = [controller performSelector:@selector(item)];
    
    if (appObj && [appObj respondsToSelector:@selector(bundleIdentifier)]) {
        return [appObj performSelector:@selector(bundleIdentifier)];
    }
    return nil;
}

static void handleNextTap(UIViewController *self) {
    NSString *bundleId = getBundleId(self);
    if (!bundleId) return;

    id appObj = nil;
    if ([self respondsToSelector:@selector(app)]) appObj = [self performSelector:@selector(app)];
    if (!appObj && [self respondsToSelector:@selector(item)]) appObj = [self performSelector:@selector(item)];
    if (!appObj) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:appObj];
    if (![backups isKindOfClass:[NSArray class]] || backups.count == 0) return;

    // Ascending sort for sequential
    NSArray *sortedBackups = [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        return [[b1 valueForKey:@"fileDate"] compare:[b2 valueForKey:@"fileDate"]];
    }];

    if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
    NSInteger currentIndex = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    if (currentIndex >= sortedBackups.count) currentIndex = 0;

    id targetBackup = sortedBackups[currentIndex];
    NSString *path = [targetBackup valueForKey:@"path"] ?: [targetBackup valueForKey:@"filePath"];
    if (!path) return;

    [[%c(BackupList) sharedInstance] restoreApp:appObj fromPathBackup:path progress:nil withCompletion:^{
        NSInteger nextIndex = (currentIndex + 1) % sortedBackups.count;
        [appCurrentRunIndex setObject:@(nextIndex) forKey:bundleId];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self respondsToSelector:@selector(updateNextBackupButton)]) {
                [self performSelector:@selector(updateNextBackupButton)];
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restored" 
                                                                           message:[NSString stringWithFormat:@"Finished Run %ld", (long)currentIndex] 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

static void updateButton(UIViewController *self) {
    if (!self.navigationItem) return;
    
    // Only show if we have an app selected
    id appObj = nil;
    if ([self respondsToSelector:@selector(app)]) appObj = [self performSelector:@selector(app)];
    if (!appObj && [self respondsToSelector:@selector(item)]) appObj = [self performSelector:@selector(item)];
    if (!appObj) return;

    NSString *bundleId = getBundleId(self);
    NSInteger idx = 0;
    if (bundleId && appCurrentRunIndex) {
        idx = [[appCurrentRunIndex objectForKey:bundleId] integerValue];
    }

    NSString *title = [NSString stringWithFormat:@"Next (Run:%ld)", (long)idx];
    UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(handleNextBackupTap)];
    
    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray new];
    NSInteger existing = -1;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIBarButtonItem *item = (UIBarButtonItem *)items[i];
        if ([item.title containsString:@"Next (Run:"]) { existing = (NSInteger)i; break; }
    }
    if (existing != -1) [items replaceObjectAtIndex:(NSUInteger)existing withObject:btn];
    else [items addObject:btn];
    self.navigationItem.rightBarButtonItems = items;
}

// Hook for Screenshot 2
%hook BackupsTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButton]; }
%new - (void)updateNextBackupButton { updateButton(self); }
%new - (void)handleNextBackupTap { handleNextTap(self); }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    NSString *bundleId = getBundleId(self);
    if (!bundleId) return;

    id appObj = nil;
    if ([self respondsToSelector:@selector(app)]) appObj = [self performSelector:@selector(app)];
    if (!appObj) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:appObj];
    if ([backups isKindOfClass:[NSArray class]] && backups.count > 0 && indexPath.section == 0) {
        NSInteger total = (NSInteger)backups.count;
        if (indexPath.row < total) {
            // UI is Newest First (Descending)
            // Run is Ascending
            NSInteger ascendingIdx = total - 1 - indexPath.row;
            if (!appCurrentRunIndex) appCurrentRunIndex = [NSMutableDictionary new];
            [appCurrentRunIndex setObject:@(ascendingIdx) forKey:bundleId];
            dispatch_async(dispatch_get_main_queue(), ^{ [self updateNextBackupButton]; });
        }
    }
}
%end

// Hook for Screenshot 1
%hook AppInfoTableViewController
- (void)viewWillAppear:(BOOL)animated { %orig; [self updateNextBackupButton]; }
%new - (void)updateNextBackupButton { updateButton(self); }
%new - (void)handleNextBackupTap { handleNextTap(self); }
%end

// Sorting
%hook BackupList
- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    if (![backups isKindOfClass:[NSArray class]] || backups.count < 2) return backups;
    return [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        return [[b2 valueForKey:@"fileDate"] compare:[b1 valueForKey:@"fileDate"]];
    }];
}
%end
