//
//  vaavudAppDelegate.m
//  VaavudCore
//
//  Created by Andreas Okholm on 5/8/13.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import "AppDelegate.h"
#import <Crashlytics/Crashlytics.h>
#import "ModelManager.h"
#import "ServerUploadManager.h"
#import "LocationManager.h"
#import "QueryStringUtil.h"
#import "TabBarController.h"
#import "TMCache.h"
#import "AccountManager.h"
#import "Mixpanel.h"
#import "Property+Util.h"
#import "UnitUtil.h"
#import "UIColor+VaavudColors.h"
#import "MixpanelUtil.h"
#import "Vaavud-Swift.h"

@interface AppDelegate() <DBRestClientDelegate>

@property (nonatomic, strong) NSDate *lastAppActive;
@property (nonatomic) DropboxUploader *dropboxUploader;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4*1024*1024 diskCapacity:20*1024*1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    TMCache *cache = [TMCache sharedCache];
    cache.diskCache.ageLimit = 24.0*3600.0;
    
    [MagicalRecord setupAutoMigratingCoreDataStack];
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelOff];
    
    [[ModelManager sharedInstance] initializeModel];
    [[ServerUploadManager sharedInstance] start];
    [[LocationManager sharedInstance] startIfEnabled];
    //[FBSettings setLoggingBehavior:[NSSet setWithObjects:FBLoggingBehaviorFBRequests, FBLoggingBehaviorInformational, nil]];
            
    self.xCallbackSuccess = nil;

    if ([Property isMixpanelEnabled]) {
        [Mixpanel sharedInstanceWithToken:@"757f6311d315f94cdfc8d16fb4d973c0"];

        // if logged in, make sure Mixpanel knows the Vaavud user ID
        if ([[AccountManager sharedInstance] isLoggedIn] && [Property getAsString:KEY_USER_ID]) {
            [[Mixpanel sharedInstance] identify:[Property getAsString:KEY_USER_ID]];
        }
    }
    
    [Crashlytics startWithAPIKey:@"767b68b0d4b5e7c052c4de75ae8859beee5d9901"];
    
    //dropbox
    [DBSession setSharedSession:[[DBSession alloc] initWithAppKey:@"zszsy52n0svxcv7" appSecret:@"t39k1uzaxs7a0zj" root:kDBRootAppFolder]];
    
    // Whenever a person opens the app, check for a cached session and refresh token
    if ([[AccountManager sharedInstance] isLoggedIn]) {
        [[AccountManager sharedInstance] registerWithFacebook:nil action:AuthenticationActionRefresh];
    }
    
    // set has wind meter property if not set
    if (![Property getAsString:KEY_USER_HAS_WIND_METER]) {
        [Property refreshHasWindMeter];
    }
    
    [Property setAsBoolean:[Property getAsBoolean:KEY_MAP_GUIDE_MEASURE_BUTTON_SHOWN] forKey:KEY_MAP_GUIDE_MEASURE_BUTTON_SHOWN_TODAY];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *viewController = nil;
        
    // CORE VAAVUD APP
    NSString *vcName;
    
    if ([Property getAsBoolean:KEY_HAS_SEEN_INTRO_FLOW defaultValue:NO]) {
        // Not a new user
        if (LOG_INTRO) NSLog(@"KEY_HAS_SEEN_INTRO_FLOW");

        if ([Property getAsBoolean:KEY_HAS_SEEN_TRISCREEN_FLOW defaultValue:NO]) {
            // Has seen upgrade flow
            if (LOG_INTRO) NSLog(@"KEY_HAS_SEEN_TRISCREEN_FLOW");
            vcName = @"TabBarController";
        }
        else {
            // Has not seen upgrade flow
            if (LOG_INTRO) NSLog(@"NOT KEY_HAS_SEEN_TRISCREEN_FLOW");
            vcName = @"UpgradingUserViewController";
        }
    }
    else {
        // Has not seen intro flow so we will show it now
        if (LOG_INTRO) NSLog(@"not KEY_HAS_SEEN_INTRO_FLOW");

        vcName = @"FirstTimeFlowController";
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    viewController = [storyboard instantiateViewControllerWithIdentifier:vcName];
    
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [FBAppCall handleDidBecomeActive];
    
    if ([Property isMixpanelEnabled]) {
        [MixpanelUtil registerUserAsMixpanelProfile];
        [MixpanelUtil updateMeasurementProperties:YES];

        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        
        // Mixpanel super properties
        NSDate *creationTime = [Property getAsDate:KEY_CREATION_TIME];
        if (creationTime) {
            [mixpanel registerSuperPropertiesOnce:@{@"Creation Time": [MixpanelUtil toUTFDateString:creationTime]}];
        }
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:10];
        
        NSString *userId = [Property getAsString:KEY_USER_ID];
        if (userId) {
            [dictionary setObject:@"true" forKey:@"User"];
        }

        NSString *facebookUserId = [Property getAsString:KEY_FACEBOOK_USER_ID];
        if (facebookUserId) {
            [dictionary setObject:@"true" forKey:@"Facebook"];
        }

        NSString *language = [Property getAsString:KEY_LANGUAGE];
        if (language) {
            [dictionary setObject:language forKey:@"Language"];
        }
        
        NSNumber *windSpeedUnit = [Property getAsInteger:KEY_WIND_SPEED_UNIT];
        if (windSpeedUnit) {
            NSString *unit = [UnitUtil jsonNameForWindSpeedUnit:[windSpeedUnit intValue]];
            [dictionary setObject:unit forKey:@"Speed Unit"];
        }
        
        BOOL enableShareDialog = [Property getAsBoolean:KEY_ENABLE_SHARE_DIALOG defaultValue:YES];
        [dictionary setObject:(enableShareDialog ? @"true" : @"false") forKey:@"Enable Share Dialog"];
        
        if (dictionary.count > 0) {
            [mixpanel registerSuperProperties:dictionary];
        }
    }
    
    if (self.lastAppActive == nil || fabs([self.lastAppActive timeIntervalSinceNow]) > 30.0*60.0 /* 30 mins */) {
        if ([Property isMixpanelEnabled]) {
            [[Mixpanel sharedInstance] track:@"Open App"];
        }
        self.lastAppActive = [NSDate date];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    if ([url.scheme isEqualToString:@"vaavud"]) {
        NSDictionary *dict = [QueryStringUtil parseQueryString:url.query];
        
        self.xCallbackSuccess = nil;
        
        if ([url.host isEqualToString:@"x-callback-url"]) {
            if ([url.path isEqualToString:@"/measure"]) {
                [VEVaavudElectronicSDK sharedVaavudElectronic];
                self.xCallbackSuccess = [dict objectForKey:@"x-success"];
                
                if ([self.window.rootViewController isKindOfClass:[TabBarController class]]) {
                    TabBarController *tabBarController = (TabBarController *)self.window.rootViewController;
                    if (tabBarController != nil && tabBarController.isViewLoaded) {
                        [tabBarController takeMeasurementFromUrlScheme];
                    }
                }
            }
        }
    }
    else if ([[DBSession sharedSession] handleOpenURL:url]) {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:KEY_IS_DROPBOXLINKED
         object:@([[DBSession sharedSession] isLinked])];
        return YES;
    }
    else {
        return [FBSession.activeSession handleOpenURL:url];
    }
    
    return YES;
}

#pragma mark - Dropbox

-(void)uploadToDropbox:(MeasurementSession *)session {
    if (!self.dropboxUploader) {
        self.dropboxUploader = [[DropboxUploader alloc] initWithDelegate:self];
    }
    
    [self.dropboxUploader uploadToDropbox:session];
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
              from:(NSString *)srcPath metadata:(DBMetadata *)metadata {
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:srcPath error:&error];
    if (!error) {
        NSLog(@"File uploaded and deleted successfully to path: %@", metadata.path);
    }
    else {
        NSLog(@"File uploaded successfully, but not deleted to path: %@, error: %@", metadata.path, error.localizedDescription);
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {
    NSLog(@"File upload failed with error: %@", error);
}

- (void)userAuthenticated:(BOOL)isSignup viewController:(UIViewController *)viewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UIViewController *nextViewController = [storyboard instantiateViewControllerWithIdentifier:@"TabBarController"];
    //nextViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    //[viewController presentViewController:nextViewController animated:YES completion:nil];
    self.window.rootViewController = nextViewController;
    
    [[ServerUploadManager sharedInstance] syncHistory:2 ignoreGracePeriod:YES success:nil failure:nil];
}

- (void)cancelled:(UIViewController *)viewController {
}

- (NSString *)registerScreenTitle {
    return nil;
}

- (NSString *)registerTeaserText {
    return nil;
}

@end
