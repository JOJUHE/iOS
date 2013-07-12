//
//  vaavudCoreController.m
//  VaavudCore
//
//  Created by Andreas Okholm on 5/8/13.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import "vaavudAppDelegate.h"
#import "VaavudCoreController.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreData/CoreData.h>
#import "VaavudMagneticFieldDataManager.h"
#import "vaavudFFT.h"
#import "MeasurementSession.h"
#import "MeasurementPoint.h"
#import "UUIDUtil.h"
#import "ServerUploadManager.h"
#import "LocationManager.h"
#import "Property+Util.h"

@interface VaavudCoreController () {
    
}

// public properties - create setters
@property (nonatomic, strong) NSNumber *setWindDirection;
@property (nonatomic, strong) NSMutableArray *windSpeed;
@property (nonatomic, strong) NSMutableArray *isValid;
@property (nonatomic, strong) NSMutableArray *windSpeedTime;
@property (nonatomic, strong) NSMutableArray *windDirectionTime;
@property (nonatomic, strong) NSMutableArray *windDirection;
@property (nonatomic, strong) NSDate *startTime;


 // private properties
@property (nonatomic, strong) VaavudMagneticFieldDataManager *sharedMagneticFieldDataManager;
@property (nonatomic, strong) vaavudDynamicsController *vaavudDynamicsController;
@property (nonatomic, strong) NSArray *FFTresultx;
@property (nonatomic, strong) NSArray *FFTresulty;
@property (nonatomic, strong) NSArray *FFTresultz;

@property (nonatomic, strong) vaavudFFT *FFTEngine;
@property (nonatomic) int       magneticFieldUpdatesCounter;
@property (nonatomic) NSInteger isValidPercent;
@property (nonatomic) BOOL      isValidCurrentStatus;
@property (nonatomic) BOOL      wasValidStatus;

@property (nonatomic) double    sumOfValidMeasurements;
@property (nonatomic) int       numberOfValidMeasurements;
@property (nonatomic) int       numberOfMeasurements;
@property (nonatomic) double    maxWindspeed;

@property (nonatomic) MeasurementSession *measurementSession;

- (void) updateIsValid;
- (double) convertFrequencyToWindspeed: (double) frequency;

@end


@implementation VaavudCoreController 

// Public methods

- (id) init
{
    self = [super init];
    
    if (self)
    {
        // Do initializing
        self.FFTEngine = [[vaavudFFT alloc] initFFTLength:FFTLength];
    }
    
    return self;
}

- (void) start
{
    self.dynamicsIsValid = NO;
    self.isValidPercent = 50; // start at 50% valid
    self.isValidCurrentStatus = NO;
    self.windDirectionIsConfirmed = NO;
    
    self.startTime          = [NSDate date];
    self.windSpeed          = [NSMutableArray arrayWithCapacity:1000];
    self.windSpeedTime      = [NSMutableArray arrayWithCapacity:1000];
    self.isValid            = [NSMutableArray arrayWithCapacity:1000];
    self.windDirection      = [NSMutableArray arrayWithCapacity:50];
    self.windDirectionTime  = [NSMutableArray arrayWithCapacity:50];
    self.magneticFieldUpdatesCounter = 0;
    self.numberOfValidMeasurements = 0;
    self.sumOfValidMeasurements = 0;
    
    // Set interface direction
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
        self.upsideDown = NO;
    
    if (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        self.upsideDown = YES;
    
    // create new MeasurementSession and save it in the database
    self.measurementSession = [MeasurementSession createEntity];
    self.measurementSession.uuid = [UUIDUtil generateUUID];
    self.measurementSession.device = [Property getAsString:KEY_DEVICE_UUID];
    self.measurementSession.startTime = [NSDate date];
    self.measurementSession.timezoneOffset = [NSNumber numberWithInt:[[NSTimeZone localTimeZone] secondsFromGMTForDate:self.measurementSession.startTime]];
    self.measurementSession.endTime = self.measurementSession.startTime;
    self.measurementSession.measuring = [NSNumber numberWithBool:YES];
    self.measurementSession.uploaded = [NSNumber numberWithBool:NO];
    self.measurementSession.uploadedIndex = [NSNumber numberWithInt:0];
    [self updateMeasurementSessionLocation];
    [[NSManagedObjectContext defaultContext] saveToPersistentStoreWithCompletion:nil];
    
    // create reference to MagneticField Data Manager and start
    self.sharedMagneticFieldDataManager = [VaavudMagneticFieldDataManager sharedMagneticFieldDataManager];
    self.sharedMagneticFieldDataManager.delegate = self;
    [self.sharedMagneticFieldDataManager start];
    
    // create dynamics controller and start
    self.vaavudDynamicsController = [[vaavudDynamicsController alloc] init];
    self.vaavudDynamicsController.vaavudCoreController = self;
    [self.vaavudDynamicsController start];
}

- (void) stop
{
    [self.sharedMagneticFieldDataManager stop];
    [self.vaavudDynamicsController stop];

    self.measurementSession.measuring = [NSNumber numberWithBool:NO];
    [[NSManagedObjectContext defaultContext] saveToPersistentStoreWithCompletion:^(BOOL success, NSError *error){
        if (success) {
            [[ServerUploadManager sharedInstance] triggerUpload];
        }
    }];
    
    vaavudAppDelegate *appDelegate = (vaavudAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.xCallbackSuccess && appDelegate.xCallbackSuccess != nil && appDelegate.xCallbackSuccess != (id)[NSNull null]) {
        
        NSLog(@"[VaavudCoreController] There is a pending x-success callback: %@", appDelegate.xCallbackSuccess);
        
        // TODO: this will return to the caller to quickly before we're fully uploaded to own servers
        NSString* callbackURL = [NSString stringWithFormat:@"%@?windSpeedAvg=%@&windSpeedMax=%@", appDelegate.xCallbackSuccess, self.measurementSession.windSpeedAvg, self.measurementSession.windSpeedMax];
        appDelegate.xCallbackSuccess = nil;
        
        NSLog(@"[VaavudCoreController] Trying to open callback URL: %@", callbackURL);
        
        BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:callbackURL]];
        if (!success) {
            NSLog(@"Failed to open callback URL");
        }
    }
}


- (void) remove
{
    
}

- (void) updateIsValid{
    
    if (!self.FFTisValid) {
        self.isValidPercent =0;
    }
    
    if (self.FFTisValid && self.dynamicsIsValid) {
        self.isValidPercent += 8;
    } else {
        self.isValidPercent -= 8;
    }
    
    if (self.isValidPercent > 100) {
        self.isValidPercent = 100;
        self.isValidCurrentStatus = YES;
    }
    
    if (self.isValidPercent < 0) {
        self.isValidPercent = 0;
        self.isValidCurrentStatus = NO;
    }
    
    [self.isValid addObject: [NSNumber numberWithBool: self.isValidCurrentStatus]];

    if (self.wasValidStatus != self.isValidCurrentStatus){
        [self.vaavudCoreControllerViewControllerDelegate windSpeedMeasurementsAreValid: self.isValidCurrentStatus];
    }
    
    // note: we shouldn't end up here if there isn't an active MeasurementSession with measuring=YES, but safe-guard just in case
    if ((self.numberOfValidMeasurements % saveEveryNthPoint == 0) && [self.measurementSession.measuring boolValue] == YES) {
        
        if (self.isValidCurrentStatus) {
        
            // update location to the latest position (we might not have a fix when pressing start)
            [self updateMeasurementSessionLocation];
            
            // always update measurement session's endtime and summary info
            self.measurementSession.endTime = [NSDate date];
            self.measurementSession.windSpeedAvg = [self getAverage];
            self.measurementSession.windSpeedMax = [self getMax];
            self.measurementSession.windDirection = self.setWindDirection;
 
            // add MeasurementPoint and save to database
            MeasurementPoint *measurementPoint = [MeasurementPoint createEntity];
            measurementPoint.session = self.measurementSession;
            measurementPoint.time = [NSDate date];
            measurementPoint.windSpeed = [self.windSpeed objectAtIndex:self.numberOfMeasurements - 1];
            measurementPoint.windDirection = [self.windDirection lastObject];

            [[NSManagedObjectContext defaultContext] saveToPersistentStoreWithCompletion:nil];

        }
        else if (self.wasValidStatus) {
            
            // current measurement is not valid, but the previous one was, so add a point indicating that there is a "hole" in the data

            MeasurementPoint *measurementPoint = [MeasurementPoint createEntity];
            measurementPoint.session = self.measurementSession;
            measurementPoint.time = [NSDate date];
            measurementPoint.windSpeed = nil;
            measurementPoint.windDirection = nil;        
            
            [[NSManagedObjectContext defaultContext] saveToPersistentStoreWithCompletion:nil];
        }
    }
    
    self.wasValidStatus = self.isValidCurrentStatus;
}

// protocol method
- (void) DynamicsIsValid: (BOOL) validity
{
    self.dynamicsIsValid = validity;
}

- (void) newHeading: (NSNumber*) newHeading
{
    
    if (self.upsideDown){
        double heading;
        heading = [newHeading doubleValue];
        
        if (heading > 180)
            heading -= 180;
        else
            heading += 180;
        
        newHeading = [NSNumber numberWithDouble: heading];
        
    }
    
    [self.windDirection addObject: newHeading];
    [self.windDirectionTime addObject: [NSNumber numberWithDouble: [self.startTime timeIntervalSinceDate: [NSDate date]]]];
    
    if (!self.windDirectionIsConfirmed)
        self.setWindDirection = newHeading;
}


// protocol method
- (void) magneticFieldValuesUpdated
{
    self.magneticFieldUpdatesCounter += 1;
    
    if (self.magneticFieldUpdatesCounter > FFTDataLength){
        
        if ( self.magneticFieldUpdatesCounter % 3 == 0 ) {
            
            int modulus = self.magneticFieldUpdatesCounter % 9 / 3;
                        
            NSRange subArrayRange = NSMakeRange(self.magneticFieldUpdatesCounter - FFTDataLength, FFTDataLength);
            
            switch (modulus) {
                case 0:
                    self.FFTresultx = [self.FFTEngine doFFT: [self.sharedMagneticFieldDataManager.magneticFieldReadingsx subarrayWithRange:subArrayRange]];
                    break;
                case 1:
                    self.FFTresulty = [self.FFTEngine doFFT: [self.sharedMagneticFieldDataManager.magneticFieldReadingsy subarrayWithRange:subArrayRange]];
                    break;
                case 2:
                    self.FFTresultz = [self.FFTEngine doFFT: [self.sharedMagneticFieldDataManager.magneticFieldReadingsz subarrayWithRange:subArrayRange]];
                    break;
                    
                default:
                    NSLog(@"You should not be here!");
                    break;
            }
            
            // create average
            int resultArrayLength = FFTLength/2;
            
            
            NSMutableArray *FFTaverage = [NSMutableArray arrayWithCapacity: resultArrayLength];
            
            for (int i = 0; i < resultArrayLength; i++) {
                
                double mean = ( [[self.FFTresultx objectAtIndex:i ] doubleValue] + [[self.FFTresulty objectAtIndex:i ] doubleValue] + [[self.FFTresultz objectAtIndex:i ] doubleValue] ) / 3;
                
                [FFTaverage insertObject:[NSNumber numberWithDouble: mean] atIndex: i];
            }
            
            
            // calculate actual sample frequency
            
            NSArray *timeSeries = [self.sharedMagneticFieldDataManager.magneticFieldReadingsTime subarrayWithRange: subArrayRange];
            
            double timeDifference = [[timeSeries lastObject] doubleValue] - [[timeSeries objectAtIndex:0] doubleValue];
            
            double actualSampleFrequency = (FFTDataLength-1)/timeDifference;
            
            // use quadratic interpolation to find peak
            // Calculate max peak
            double maxPeak = 0;
            double alpha, beta, gamma, p, dominantFrequency, frequencyMagnitude;
            
            int maxBin = 0;
            
            for (int i=0; i<FFTLength/2; i++) {
                
                if ([[FFTaverage objectAtIndex:i] doubleValue] > maxPeak){
                    maxBin = i;
                    maxPeak = [[FFTaverage objectAtIndex:i] doubleValue];
                }
            }
            
            if ((maxBin > 0) && (maxBin < FFTLength/2 -1)) {
                alpha = [[FFTaverage objectAtIndex: maxBin-1 ] doubleValue];
                beta = [[FFTaverage objectAtIndex: maxBin ] doubleValue];
                gamma = [[FFTaverage objectAtIndex: maxBin+1 ] doubleValue];
                
                p = (alpha - gamma) / (2*(alpha - 2*beta + gamma));
                
                dominantFrequency  = (maxBin+p)*actualSampleFrequency/FFTLength;
                frequencyMagnitude = beta - 1/4 * (alpha - gamma) * p;
                
            } else {
                dominantFrequency = 0;
                frequencyMagnitude = 0;
            }
            
            // windspeed
            
            double windspeed = [self  convertFrequencyToWindspeed: dominantFrequency];
            
            [self.windSpeed addObject: [NSNumber numberWithDouble: windspeed]];
            [self.windSpeedTime addObject: [self.sharedMagneticFieldDataManager.magneticFieldReadingsTime lastObject]];
            
            
            if (frequencyMagnitude > FFTpeakMagnitudeMinForValid) {
                self.FFTisValid = YES;
                
                self.sumOfValidMeasurements += windspeed;
                self.numberOfValidMeasurements ++;
                if (windspeed > self.maxWindspeed)
                    self.maxWindspeed = windspeed;
            }
            else {
                self.FFTisValid = NO;
                // TODO: reinsert
                //NSLog(@"FFTpeakMagnetude too low - value: @%f", frequencyMagnitude);
            }
            
            self.numberOfMeasurements++;
            [self updateIsValid];
                        
            
        } // run every X update
    } // if counter > datalength
}

- (NSNumber *) getAverage
{
    return [NSNumber numberWithDouble: self.sumOfValidMeasurements/self.numberOfValidMeasurements];
}
- (NSNumber *) getMax
{
    return [NSNumber numberWithDouble: self.maxWindspeed];
}

- (NSNumber *) getProgress
{
    
    float elapsedTime = [[self.windSpeedTime lastObject] floatValue];
    float measurementFrequency = self.numberOfMeasurements/elapsedTime;
    float validTime = self.numberOfValidMeasurements / measurementFrequency;

    
    double progress = validTime/minimumNumberOfSeconds;
    if (progress > 1)
        progress = 1;
    
    return [NSNumber numberWithDouble: progress];
}


- (double) convertFrequencyToWindspeed: (double) frequency {
    
    // Based on 09.07.2013 Windtunnel test. Parametes can be found in windTunnelAnalysis_9_07_2013.xlsx
    double windspeed = 0.9929209 * frequency + 0.2382594;
    
    if (frequency > 17.65 && frequency < 28.87) {
        windspeed = windspeed + -0.068387 * pow((frequency - 23.2667), 2) + 2.153493;
    } 
    
    return windspeed;
}


- (void) updateMeasurementSessionLocation {
    CLLocationCoordinate2D latestLocation = [LocationManager sharedInstance].latestLocation;
    if ([LocationManager isCoordinateValid:latestLocation]) {
        self.measurementSession.latitude = [NSNumber numberWithDouble:latestLocation.latitude];
        self.measurementSession.longitude = [NSNumber numberWithDouble:latestLocation.longitude];
    }
    else {
        self.measurementSession.latitude = nil;
        self.measurementSession.longitude = nil;
    }
}

@end
