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

+ (ServerUploadManager *) sharedInstance;

- (void) start;

- (void) triggerUpload;

@end
