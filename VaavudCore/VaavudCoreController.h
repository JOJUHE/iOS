//
//  vaavudCoreController.h
//  VaavudCore
//
//  Created by Andreas Okholm on 5/8/13.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VaavudMagneticFieldDataManager.h"

@interface VaavudCoreController : NSObject <VaavudMagneticFieldDataManagerDelegate>

- (id) init;
- (void) start;
- (void) stop;
- (void) remove;
- (void) magneticFieldValuesUpdated;

//@property (readonly, nonatomic, strong) NSMutableArray *magneticFieldReadings;
@property (readonly, nonatomic) float windSpeed;
@property (readonly, nonatomic) float windDirection;
@property (readonly, nonatomic) float windSpeedMax;


@end
