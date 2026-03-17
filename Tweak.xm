#import <UIKit/UIKit.h>

@interface ADBackupInfo : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSDate *fileDate;
@property (nonatomic, retain) NSString *path;
@end

@interface BackupList : NSObject
+ (id)sharedInstance;
- (NSArray *)backupsForApp:(id)app;
- (void)restoreApp:(id)app fromPathBackup:(NSString *)path progress:(id)progress withCompletion:(id)completion;
@end

@interface BackupsTableViewController : UITableViewController
@property (nonatomic, retain) id app; // The app object this controller is showing backups for
- (void)reloadBackups;
@end

// Global or static dictionary to keep track of the current backup index per app
static NSMutableDictionary *appNextBackupIndex;

%hook BackupsTableViewController

- (void)viewDidLoad {
    %orig;
    
    // Add "Next Backup" button to navigation bar
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:@"Next Backup" 
                                                                   style:UIBarButtonItemStylePlain 
                                                                  target:self 
                                                                  action:@selector(handleNextBackupTap)];
    self.navigationItem.rightBarButtonItems = [self.navigationItem.rightBarButtonItems arrayByAddingObject:nextButton];
}

%new
- (void)handleNextBackupTap {
    if (!appNextBackupIndex) {
        appNextBackupIndex = [NSMutableDictionary new];
    }
    
    NSString *bundleId = [self.app valueForKey:@"bundleIdentifier"]; // Assuming app has this
    if (!bundleId) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:self.app];
    
    // Sort backups by date (Ascending)
    NSArray *sortedBackups = [backups sortedArrayUsingComparator:^NSComparisonResult(ADBackupInfo *map1, ADBackupInfo *map2) {
        return [map1.fileDate compare:map2.fileDate];
    }];

    if (sortedBackups.count == 0) return;

    // Get current index
    NSInteger currentIndex = [[appNextBackupIndex objectForKey:bundleId] integerValue];
    
    // Safety check if index is out of bounds (e.g. if backups were deleted)
    if (currentIndex >= sortedBackups.count) {
        currentIndex = 0;
    }

    ADBackupInfo *nextBackup = sortedBackups[currentIndex];
    
    // Proceed to restore
    [[%c(BackupList) sharedInstance] restoreApp:self.app 
                                 fromPathBackup:nextBackup.path 
                                       progress:nil 
                                 withCompletion:^{
        // Increment and save index for next time (with wrap-around)
        NSInteger nextIndex = (currentIndex + 1) % sortedBackups.count;
        [appNextBackupIndex setObject:@(nextIndex) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_content_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" 
                                                                           message:[NSString NSFormat:@"Restored: %@", nextBackup.name] 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

%end

// Hook the sorting in the data source as well to ensure consistent display
%hook BackupList

- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    // Return backups sorted by date (Descending for UI usually, but user asked for sorting)
    // We'll sort Descending for the list view so newest is at top, but the "Next" logic uses Ascending if preferred
    return [backups sortedArrayUsingComparator:^NSComparisonResult(ADBackupInfo *map1, ADBackupInfo *map2) {
        return [map2.fileDate compare:map1.fileDate]; // Newest first for UI
    }];
}

%end
