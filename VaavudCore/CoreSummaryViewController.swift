//
//  CoreSummaryViewController.swift
//  Vaavud
//
//  Created by Gustaf Kugelberg on 22/01/15.
//  Copyright (c) 2015 Andreas Okholm. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class CoreSummaryViewController: UIViewController, MKMapViewDelegate, UIAlertViewDelegate {
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var averageLabel: UILabel!
    @IBOutlet private weak var maximumLabel: UILabel!
    @IBOutlet private weak var locationLabel: UILabel!
    
    @IBOutlet private weak var averageUnitLabel: UILabel!
    @IBOutlet private weak var maximumUnitLabel: UILabel!
    
    @IBOutlet private weak var sleipnirView: SleipnirView!
    @IBOutlet private weak var upsellLabel: UILabel!
    
    @IBOutlet private weak var directionView: ArrowView!
    @IBOutlet private weak var directionButton: UIButton!
    
    @IBOutlet private weak var pressureLabel: UILabel!
    @IBOutlet private weak var pressureUnitLabel: UILabel!
    
    @IBOutlet private weak var temperatureLabel: UILabel!
    @IBOutlet private weak var temperatureUnitLabel: UILabel!
    
    @IBOutlet private weak var windchillLabel: UILabel!
    @IBOutlet private weak var windchillUnitLabel: UILabel!
    
    @IBOutlet private weak var gustinessLabel: UILabel!
    @IBOutlet private weak var gustinessUnitLabel: UILabel!
    
    @IBOutlet private weak var mapView: MKMapView!
    
    @IBOutlet private weak var pressureView: PressureView!
    private var pressureItem: DynamicReadingItem!
    @IBOutlet private weak var temperatureView: TemperatureView!
    private var temperatureItem: DynamicReadingItem!
    @IBOutlet private weak var windchillView: WindchillView!
    private var windchillItem: DynamicReadingItem!
    @IBOutlet private weak var gustinessView: GustinessView!
    private var gustinessItem: DynamicReadingItem!
    
    // <--- To be removed when storyboard is localized
    
    @IBOutlet weak var averageHeadingLabel: UILabel!
    @IBOutlet weak var maxHeadingLabel: UILabel!
    @IBOutlet weak var pressureHeadingLabel: UILabel!
    @IBOutlet weak var temperatureHeadingLabel: UILabel!
    @IBOutlet weak var windchillHeadingLabel: UILabel!
    @IBOutlet weak var gustinessHeadingLabel: UILabel!
    
    @IBOutlet weak var northLabel: UIButton!
    @IBOutlet weak var southLabel: UIButton!
    @IBOutlet weak var eastLabel: UIButton!
    @IBOutlet weak var westLabel: UIButton!
    
    // To be removed when storyboard is localized --->

    private var hasSomeDirection: Float? = nil
    private var hasActualDirection = false
    private var isShowingDirection = false
    private var hasWindSpeed = false
    private var hasTemperature = false
    private var hasPressure = false
    private var hasGustiness = false
    private var hasWindChill = false
    
    private var animator: UIDynamicAnimator!
    private var formatter = VaavudFormatter()
    var session: MeasurementSession!
    
    override func viewDidLoad() {
        animator = UIDynamicAnimator(referenceView: view)
        pressureItem = DynamicReadingItem(readingView: pressureView)
        temperatureItem = DynamicReadingItem(readingView: temperatureView)
        windchillItem = DynamicReadingItem(readingView: windchillView)
        gustinessItem = DynamicReadingItem(readingView: gustinessView)
        
        title = formatter.localizedTitleDate(session.startTime)
        
        setupMapView()
        setupUI()
        setupLocalUI()
    }
    
    private func setupMapView() {
        if session.latitude == nil || session.longitude == nil {
            mapView.alpha = 0.5
            mapView.userInteractionEnabled = false
            return
        }
        
        let coord = CLLocationCoordinate2D(latitude: session.latitude.doubleValue, longitude: session.longitude.doubleValue)
        mapView.setRegion(MKCoordinateRegionMakeWithDistance(coord, 500, 500), animated: false)
    }
    
    private func setupUI() {
        if let time = formatter.localizedTime(session.startTime) {
            dateLabel.text = time.uppercaseString
        }
        
        if let geoName = session.geoLocationNameLocalized {
            if geoName == "GEOLOCATION_UNKNOWN" {
                locationLabel.text = NSLocalizedString("GEOLOCATION_UNKNOWN", comment: "")
            }
            else {
                locationLabel.text = geoName
            }
        }
        
        updateWindDirection(session)
        updateWindSpeeds(session)
        updatePressure(session)
        updateTemperature(session)
        updateGustiness(session)
    }
    
    private func setupLocalUI() {
        northLabel.setTitle(formatter.localizedNorth, forState: .Normal)
        southLabel.setTitle(formatter.localizedSouth, forState: .Normal)
        eastLabel.setTitle(formatter.localizedEast, forState: .Normal)
        westLabel.setTitle(formatter.localizedWest, forState: .Normal)

        upsellLabel.text = NSLocalizedString("SUMMARY_UPSELL", comment: "")
        
        pressureHeadingLabel.text = NSLocalizedString("SUMMARY_PRESSURE", comment: "").uppercaseString
        temperatureHeadingLabel.text = NSLocalizedString("SUMMARY_TEMPERATURE", comment: "").uppercaseString
        windchillHeadingLabel.text = NSLocalizedString("SUMMARY_WIND_CHILL", comment: "").uppercaseString
        gustinessHeadingLabel.text = NSLocalizedString("SUMMARY_GUSTINESS", comment: "").uppercaseString

        maxHeadingLabel.text = NSLocalizedString("HEADING_MAX", comment: "").uppercaseString
        averageHeadingLabel.text = NSLocalizedString("HEADING_AVERAGE", comment: "").uppercaseString
    }
    
    private func showSleipnir() {
        sleipnirView.alpha = 1
        upsellLabel.alpha = 1
        directionView.alpha = 0
        directionButton.alpha = 0
    }
    
    private func showDirection() {
        sleipnirView.alpha = 0
        upsellLabel.alpha = 0
        directionView.alpha = 1
        directionButton.alpha = 1
    }
    
    @IBAction private func tappedCompass(sender: AnyObject) {
        println("tapped compass")
        if isShowingDirection {
            println("showing compass")
            if !hasActualDirection {
                showAndHideSleipnir()
            }
            else if hasSomeDirection != nil {
                tappedWindDirection(sender)
            }
        }
        else {
            println("not showing compass")
            tappedSleipnir(sender)
        }
    }
    
    private func showAndHideSleipnir(delay: Double = 4) {
        isShowingDirection = false
        UIView.animateWithDuration(0.2)  { self.showSleipnir() }
        UIView.animateWithDuration(0.2, delay: 2, options: nil, animations: { self.showDirection() }, completion: { (Bool) -> Void in
            self.isShowingDirection = true
        })
    }
    
    @IBAction private func tappedSleipnir(sender: AnyObject) {
        println("sleipnir action")

        let title = NSLocalizedString("SUMMARY_MEASURE_WINDDIRECTION", comment: "")
        let message = NSLocalizedString("SUMMARY_WITH_SLEIPNIR_WINDDIRECTION", comment: "")
        let cancel = NSLocalizedString("BUTTON_CANCEL", comment: "")
        let other = NSLocalizedString("INTRO_UPGRADE_CTA_BUY", comment: "")
        showAlert(title, message: message, cancel: cancel, other: other)
    }
    
    func showAlert(title: String, message: String, cancel: String, other: String) {
        if objc_getClass("UIAlertController") == nil {
            UIAlertView(title: title, message: message, delegate: self, cancelButtonTitle: cancel, otherButtonTitles: other).show()
        }
        else {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: cancel, style: .Cancel, handler: { (action) -> Void in }))
            alert.addAction(UIAlertAction(title: other, style: .Default, handler: { (action) -> Void in self.openBuySleipnir() }))
            presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 1 {
            openBuySleipnir()
        }
    }
    
    func openBuySleipnir() {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://vaavud.com/product/vaavud-sleipnir")!)
    }
    
    @IBAction func tappedWindDirection(sender: AnyObject) {
        formatter.directionUnit = formatter.directionUnit.next
        updateWindDirection(session)
    }
    
    @IBAction func tappedPressure(sender: AnyObject) {
        if hasPressure {
            animator.removeAllBehaviors()
            snap(pressureItem, to: CGFloat(arc4random() % 100))
            
            formatter.pressureUnit = formatter.pressureUnit.next
            updatePressure(session)
        }
    }

    @IBAction func tappedTemperature(sender: AnyObject) {
        if hasTemperature {
            animator.removeAllBehaviors()
            snap(temperatureItem, to: CGFloat(arc4random() % 100))
            snap(windchillItem, to: CGFloat(arc4random() % 100))
            
            formatter.temperatureUnit = formatter.temperatureUnit.next
            updateTemperature(session)
        }
    }
    
    @IBAction func tappedWindSpeed(sender: AnyObject) {
        if hasWindSpeed {
            formatter.windSpeedUnit = formatter.windSpeedUnit.next
            updateWindSpeeds(session)
        }
    }
    
    @IBAction func tappedGustiness(sender: AnyObject) {
        if hasGustiness {
            animator.removeAllBehaviors()
            gustinessItem.center = CGPoint()
            snap(gustinessItem, to: 1000)
        }
    }
    
    private func animateAll() {
        animator.removeAllBehaviors()
        gustinessItem.center = CGPoint()
        snap(pressureItem, to: CGFloat(arc4random() % 100))
        snap(temperatureItem, to: CGFloat(arc4random() % 100))
        snap(windchillItem, to: CGFloat(arc4random() % 100))
        snap(gustinessItem, to: 1000)
    }
    
    private func updateWindSpeeds(ms: MeasurementSession) {
        hasWindSpeed = false

        if let average = formatter.localizedWindspeed(ms.windSpeedAvg?.floatValue) {
            averageUnitLabel.text = formatter.windSpeedUnit.localizedString
            averageLabel.text = average
            hasWindSpeed = true
        }
        else {
            averageUnitLabel.text = ""
            averageLabel.text = formatter.missingValue
        }
        
        if let maximum = formatter.localizedWindspeed(ms.windSpeedMax?.floatValue) {
            maximumUnitLabel.text = formatter.windSpeedUnit.localizedString
            maximumLabel.text = maximum
            hasWindSpeed = true
        }
        else {
            maximumUnitLabel.text = ""
            maximumLabel.text = formatter.missingValue
        }
    }
    
    private func updateWindDirection(ms: MeasurementSession) {
        hasActualDirection = session.windDirection != nil

        hasSomeDirection = (session.windDirection ?? session.sourcedWindDirection)?.floatValue
        hasSomeDirection = session.windDirection?.floatValue // FIXME: Temporary, will remove when we start sourcing directions
        
        if let rotation = hasSomeDirection {
            let t = CGAffineTransformMakeRotation(π*CGFloat(1 + rotation/180))
            
            UIView.animateWithDuration(0.3, delay: 0.2, options: nil, animations: { self.directionView.transform = t }, completion: { (done) -> Void in
                self.animateAll()
            })
            
            directionButton.setTitle(formatter.localizedDirection(rotation), forState: .Normal)
            
            showDirection()
            isShowingDirection = true

            if !hasActualDirection {
                showAndHideSleipnir(delay: 5)
            }
        }
        else {
            showSleipnir()
            isShowingDirection = false
        }
    }

    private func updatePressure(ms: MeasurementSession) {
        if let pressure = formatter.localizedPressure(ms.pressure?.floatValue ?? ms.sourcedPressureGroundLevel?.floatValue) {
            pressureUnitLabel.text = formatter.pressureUnit.localizedString
            pressureLabel.text = pressure
            hasPressure = true
        }
        else {
            pressureUnitLabel.text = ""
            pressureLabel.text = formatter.missingValue
            hasPressure = false
        }
    }
    
    private func updateTemperature(ms: MeasurementSession) {
        if let temperature = formatter.localizedTemperature(ms.temperature?.floatValue ?? ms.sourcedTemperature?.floatValue) {
            temperatureUnitLabel.text = formatter.temperatureUnit.localizedString
            temperatureLabel.text = temperature
            hasTemperature = true
        }
        else {
            temperatureUnitLabel.text = ""
            temperatureLabel.text = formatter.missingValue
            hasTemperature = false
        }
        
        if let windChill = formatter.localizedWindchill(ms.windChill?.floatValue) {
            windchillUnitLabel.text = formatter.temperatureUnit.localizedString
            windchillLabel.text = windChill
            hasWindChill = true
        }
        else {
            windchillUnitLabel.text = ""
            windchillLabel.text = formatter.missingValue
            hasWindChill = false
        }
    }
    
    private func updateGustiness(ms: MeasurementSession) {
        if let gustiness = formatter.formattedGustiness(ms.gustiness?.floatValue) {
            gustinessLabel.text = gustiness
            gustinessUnitLabel.text = "%"
            hasGustiness = true
        }
        else {
            gustinessLabel.text = formatter.missingValue
            gustinessUnitLabel.text = ""
            hasGustiness = false
        }
    }
    
    private func snap(item: DynamicReadingItem, to x: CGFloat) {
        animator.addBehavior(UISnapBehavior(item: item, snapToPoint: CGPoint(x: x, y: 0)))
    }
}