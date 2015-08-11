//
//  ServerUploadManager.h
//  Vaavud
//
//  Created by Thomas Stilling Ambus on 19/06/2013.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MeasurementSession.h"

@interface ServerUploadManager : NSObject

@property (nonatomic, readonly) BOOL hasReachability;
@property (nonatomic, readonly) BOOL isHistorySyncBusy;

+ (ServerUploadManager *)sharedInstance;

- (void)start;
- (void)triggerUpload;
- (void)readMeasurements:(int)hours retry:(int)retryCount success:(void (^)(NSArray *measurements))success failure:(void (^)(NSError *error))failure;
- (void)registerDevice:(int)retryCount;
- (void)registerUser:(NSString *)action email:(NSString *)email passwordHash:(NSString *)passwordHash facebookId:(NSString *)facebookId facebookAccessToken:(NSString *)facebookAccessToken firstName:(NSString *)firstName lastName:(NSString *)lastName gender:(NSNumber *)gender verified:(NSNumber *)verified metaInfo:(NSDictionary *)metaInfo retry:(int)retryCount success:(void (^)(NSString *status, id responseObject))success failure:(void (^)(NSError *error))failure;
- (void)syncHistory:(int)retryCount ignoreGracePeriod:(BOOL)ignoreGracePeriod success:(void (^)())success failure:(void (^)(NSError *error))failure;
- (void)deleteMeasurementSession:(NSString *)measurementSessionUuid retry:(int)retryCount success:(void(^)())success failure:(void(^)(NSError *error))failure;

- (void)lookupForLat:(double)latitude long:(double)longitude success:(void(^)(NSNumber *temp, NSNumber *dir, NSNumber *press))success failure:(void(^)(NSError *error))failure;

@end
