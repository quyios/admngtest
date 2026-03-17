#import <UIKit/UIKit.h>

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(void(^)(void))completion;
@end

// Target the controller that shows the list of backups for a specific app
@interface BackupInfoTableViewController : UITableViewController
- (id)backupInfo;
- (id)app;
@end

static NSMutableDictionary *appNextBackupIndex;

%hook BackupInfoTableViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    // Safety: Ensure we have navigation controller
    if (!self.navigationItem) return;

    // Add "Next Backup" button
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:@"Next Backup" 
                                                                   style:UIBarButtonItemStylePlain 
                                                                  target:self 
                                                                  action:@selector(handleNextBackupTap)];
    
    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!items) items = [NSMutableArray new];
    
    // Check for duplicates
    BOOL alreadyExists = NO;
    for (UIBarButtonItem *item in items) {
        if ([item.title isEqualToString:@"Next Backup"]) {
            alreadyExists = YES;
            break;
        }
    }
    
    if (!alreadyExists) {
        [items addObject:nextButton];
        self.navigationItem.rightBarButtonItems = items;
    }
}

%new
- (void)handleNextBackupTap {
    // Attempt to find the app object safely
    id appObj = nil;
    if ([self respondsToSelector:@selector(app)]) {
        appObj = [self performSelector:@selector(app)];
    }
    
    if (!appObj && [self respondsToSelector:@selector(backupInfo)]) {
        id info = [self performSelector:@selector(backupInfo)];
        if (info && [info respondsToSelector:@selector(app)]) {
            appObj = [info performSelector:@selector(app)];
        }
    }
    
    if (!appObj) return;

    // Attempt to get bundle identifier
    NSString *bundleId = nil;
    if ([appObj respondsToSelector:@selector(bundleIdentifier)]) {
        bundleId = [appObj performSelector:@selector(bundleIdentifier)];
    }
    
    if (!bundleId) return;

    // Get backups through singleton
    Class blClass = %c(BackupList);
    if (!blClass) return;
    
    BackupList *bl = [blClass sharedInstance];
    if (!bl) return;

    NSArray *backups = [bl backupsForApp:appObj];
    if (![backups isKindOfClass:[NSArray class]] || backups.count == 0) return;
    
    // Sort Ascending for sequential restoration
    NSArray *sortedBackups = [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        NSDate *d1 = nil;
        NSDate *d2 = nil;
        if ([b1 respondsToSelector:@selector(fileDate)]) d1 = [b1 performSelector:@selector(fileDate)];
        if ([b2 respondsToSelector:@selector(fileDate)]) d2 = [b2 performSelector:@selector(fileDate)];
        if (![d1 isKindOfClass:[NSDate class]] || ![d2 isKindOfClass:[NSDate class]]) return NSOrderedSame;
        return [d1 compare:d2]; // Ascending
    }];

    if (!appNextBackupIndex) appNextBackupIndex = [NSMutableDictionary new];
    NSInteger currentIndex = [[appNextBackupIndex objectForKey:bundleId] integerValue];
    if (currentIndex >= sortedBackups.count) currentIndex = 0;

    id nextBackup = sortedBackups[currentIndex];
    NSString *backupPath = nil;
    if ([nextBackup respondsToSelector:@selector(path)]) backupPath = [nextBackup performSelector:@selector(path)];
    if (!backupPath && [nextBackup respondsToSelector:@selector(filePath)]) backupPath = [nextBackup performSelector:@selector(filePath)];
    
    if (!backupPath) return;

    [bl restoreApp:appObj 
    fromPathBackup:backupPath 
          progress:nil 
    withCompletion:^{
        NSInteger nextIndex = (currentIndex + 1) % sortedBackups.count;
        [appNextBackupIndex setObject:@(nextIndex) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"Restored index %ld/%ld", (long)currentIndex + 1, (long)sortedBackups.count];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

%end

// Global hook for sorting the list
%hook BackupList

- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    if (![backups isKindOfClass:[NSArray class]] || backups.count < 2) return backups;
    
    @try {
        return [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
            NSDate *d1 = nil;
            NSDate *d2 = nil;
            if ([b1 respondsToSelector:@selector(fileDate)]) d1 = [b1 performSelector:@selector(fileDate)];
            if ([b2 respondsToSelector:@selector(fileDate)]) d2 = [b2 performSelector:@selector(fileDate)];
            
            if (![d1 isKindOfClass:[NSDate class]] || ![d2 isKindOfClass:[NSDate class]]) return NSOrderedSame;
            return [d2 compare:d1]; // Descending for UI
        }];
    } @catch (NSException *e) {
        return backups;
    }
}

%end
