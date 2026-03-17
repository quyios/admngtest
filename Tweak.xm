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

static NSMutableDictionary *appNextBackupIndex;

%hook BackupsTableViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    // Safety: Only add the button if we are looking at a specific app's backups
    if (self.app) {
        // Prevent duplicate buttons if viewWillAppear is called multiple times
        BOOL alreadyHasNextButton = NO;
        for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) {
            if ([item.title isEqualToString:@"Next Backup"]) {
                alreadyHasNextButton = YES;
                break;
            }
        }

        if (!alreadyHasNextButton) {
            UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:@"Next Backup" 
                                                                           style:UIBarButtonItemStylePlain 
                                                                          target:self 
                                                                          action:@selector(handleNextBackupTap)];
            NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy];
            if (!items) items = [NSMutableArray new];
            [items addObject:nextButton];
            self.navigationItem.rightBarButtonItems = items;
        }
    }
}

%new
- (void)handleNextBackupTap {
    if (!self.app) return;
    
    if (!appNextBackupIndex) {
        appNextBackupIndex = [NSMutableDictionary new];
    }
    
    NSString *bundleId = nil;
    @try {
        bundleId = [self.app performSelector:@selector(bundleIdentifier)];
    } @catch (NSException *e) {
        // Fallback or ignore
    }
    
    if (!bundleId) return;

    NSArray *backups = [[%c(BackupList) sharedInstance] backupsForApp:self.app];
    if (!backups || backups.count == 0) return;
    
    // Sort backups by date (Ascending for sequential order)
    NSArray *sortedBackups = [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        NSDate *d1 = [b1 valueForKey:@"fileDate"];
        NSDate *d2 = [b2 valueForKey:@"fileDate"];
        return [d1 compare:d2];
    }];

    // Get current index
    NSInteger currentIndex = [[appNextBackupIndex objectForKey:bundleId] integerValue];
    if (currentIndex >= sortedBackups.count) {
        currentIndex = 0;
    }

    id nextBackup = sortedBackups[currentIndex];
    NSString *backupPath = [nextBackup valueForKey:@"path"];
    NSString *backupName = [nextBackup valueForKey:@"name"];

    // Proceed to restore
    [[%c(BackupList) sharedInstance] restoreApp:self.app 
                                 fromPathBackup:backupPath 
                                       progress:nil 
                                 withCompletion:^{
        // Increment index for next time (looping)
        NSInteger nextIndex = (currentIndex + 1) % sortedBackups.count;
        [appNextBackupIndex setObject:@(nextIndex) forKey:bundleId];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" 
                                                                           message:[NSString stringWithFormat:@"Restored: %@", backupName] 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

%end

%hook BackupList

- (NSArray *)backupsForApp:(id)app {
    NSArray *backups = %orig;
    if (!backups) return nil;
    
    // Sort Newest First for the UI list
    return [backups sortedArrayUsingComparator:^NSComparisonResult(id b1, id b2) {
        NSDate *d1 = [b1 valueForKey:@"fileDate"];
        NSDate *d2 = [b2 valueForKey:@"fileDate"];
        if (!d1 || !d2) return NSOrderedSame;
        return [d2 compare:d1]; // Descending
    }];
}

%end
