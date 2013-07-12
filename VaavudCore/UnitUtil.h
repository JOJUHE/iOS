//
//  Measure.h
//  Vaavud
//
//  Created by Thomas Stilling Ambus on 11/07/2013.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STATUTE_MILE 1609.344 // m
#define NAUTICAL_MILE 1852.0 // m

typedef enum {
    WindSpeedUnitKMH     = 0,
    WindSpeedUnitMS      = 1,
    WindSpeedUnitMPH     = 2,
    WindSpeedUnitKN      = 3
} WindSpeedUnit;

@interface UnitUtil : NSObject

+ (WindSpeedUnit) windSpeedUnitForCountry:(NSString*) countryCode;

+ (NSString*) jsonNameForWindSpeedUnit:(WindSpeedUnit) unit;

+ (NSString*) displayNameForWindSpeedUnit:(WindSpeedUnit) unit;

+ (double) displayWindSpeedFromDouble:(double) windSpeedMS unit:(WindSpeedUnit) unit;

+ (NSNumber*) displayWindSpeedFromNumber:(NSNumber*) windSpeedMS unit:(WindSpeedUnit) unit;

@end
