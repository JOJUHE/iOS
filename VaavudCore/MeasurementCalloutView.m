//
//  MeasurementCalloutView.m
//  Vaavud
//
//  Created by Thomas Stilling Ambus on 30/09/2013.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import "MeasurementCalloutView.h"
#import "UIImageView+TMCache.h"
#import "FormatUtil.h"
#import "MeasurementTableViewCell.h"
#import "UIColor+VaavudColors.h"
#import "Vaavud-Swift.h"

static NSString *cellIdentifier = @"MeasurementCell";

@implementation MeasurementCalloutView

BOOL isTableInitialized = NO;

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        isTableInitialized = NO;
    }
    return self;
}

-(void)layoutSubviews {
    if (!isTableInitialized) {
        UINib *cellNib = [UINib nibWithNibName:@"MeasurementTableViewCell" bundle:nil];
        [self.tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
        isTableInitialized = YES;
    }
    [super layoutSubviews];
}

-(void)setMeasurementAnnotation:(MeasurementAnnotation *)measurementAnnotation {
    _measurementAnnotation = measurementAnnotation;
    
    self.maxHeadingLabel.text = [NSLocalizedString(@"HEADING_MAX", nil) uppercaseStringWithLocale:[NSLocale currentLocale]]; // LOKALISERA_BORT sedan
    self.nearbyHeadingLabel.text = [NSLocalizedString(@"HEADING_NEARBY_MEASUREMENTS", nil) uppercaseStringWithLocale:[NSLocale currentLocale]]; // LOKALISERA_BORT sedan
    
    if (!isnan(self.measurementAnnotation.avgWindSpeed)) {
        self.avgLabel.text = [[VaavudFormatter shared] localizedSpeed:self.measurementAnnotation.avgWindSpeed digits:3];
    }
    else {
        self.avgLabel.text = @"-";
    }
    
    if (!isnan(self.measurementAnnotation.maxWindSpeed)) {
        self.maxLabel.text = [[VaavudFormatter shared] localizedSpeed:self.measurementAnnotation.maxWindSpeed digits:3];

    }
    else {
        self.maxLabel.text = @"-";
    }
    self.maxLabel.textColor = [UIColor vaavudColor];
    self.avgUnitLabel.text = [[VaavudFormatter shared] speedUnitLocalName];
    
    NSString *iconUrl = @"http://vaavud.com/appgfx/SmallWindMarker.png";
    NSString *markers = [NSString stringWithFormat:@"icon:%@|shadow:false|%f,%f", iconUrl, self.measurementAnnotation.coordinate.latitude, self.measurementAnnotation.coordinate.longitude];
    NSString *staticMapUrl = [NSString stringWithFormat:@"http://maps.google.com/maps/api/staticmap?markers=%@&zoom=15&size=224x224&sensor=true&key=%@", markers, GOOGLE_STATIC_MAPS_API_KEY];
    
    [self.imageView setCachedImageWithURL:[NSURL URLWithString:[staticMapUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] placeholderImage:self.placeholderImage];
    
    self.timeLabel.text = [FormatUtil formatRelativeDate:measurementAnnotation.startTime];

    if (self.measurementAnnotation.windDirection) {
        self.directionLabel.text = [[VaavudFormatter shared] localizedDirection:self.measurementAnnotation.windDirection.floatValue];
        self.directionLabel.hidden = NO;
        
        self.directionImageView.image = [UIImage imageNamed:@"WindArrow"];
        self.directionImageView.transform = [VaavudFormatter transformWithDirection:self.measurementAnnotation.windDirection.floatValue];
        self.directionImageView.hidden = NO;
    }
    else {
        self.directionImageView.hidden = YES;
        self.directionLabel.hidden = YES;
    }
    
    if (self.nearbyAnnotations.count == 0) {
        [self.tableView removeFromSuperview];
        [[self viewWithTag:1] removeFromSuperview]; // remove "Nearby Measurements" view
    }
    else {
        UITableView *measureTableView = self.tableView;
        measureTableView.delegate = self;
        measureTableView.dataSource = self;
    }
}

- (IBAction)mapButtonTapped {
    [self.mapViewController zoomToAnnotation:self.measurementAnnotation];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return ROW_HEIGHT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.nearbyAnnotations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MeasurementTableViewCell *cell = (MeasurementTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    MeasurementAnnotation *measurementAnnotation = self.nearbyAnnotations[indexPath.item];
    [cell setValues:measurementAnnotation.avgWindSpeed time:measurementAnnotation.startTime windDirection:measurementAnnotation.windDirection];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.mapViewController.isSelectingFromTableView = YES;
    MeasurementAnnotation *measurementAnnotation = self.nearbyAnnotations[indexPath.item];
    [self.mapViewController.mapView selectAnnotation:measurementAnnotation animated:NO];
}

@end
