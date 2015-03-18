//
//  TabBarControllerViewController.m
//  Vaavud
//
//  Created by Thomas Stilling Ambus on 20/09/2013.
//  Copyright (c) 2013 Andreas Okholm. All rights reserved.
//

#import "TabBarController.h"
#import "UIColor+VaavudColors.h"
#import "CustomSMCalloutDrawnBackgroundView.h"
#import "GuideView.h"

@interface TabBarController ()

@property (nonatomic) GuideView *calloutGuideView;
@property (nonatomic) SMCalloutView *calloutView;
@property (nonatomic) DismissOnTouchUIView *overlayDimmingView;
@property (nonatomic) BOOL isCalloutGuideViewShown;
@property (nonatomic) UIViewController *currentController;

@end

@implementation TabBarController

- (void) viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    self.currentController = nil;
    
    self.tabBar.tintColor = [UIColor vaavudColor];
    
    NSArray* topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"GuideView" owner:self options:nil];
    self.calloutGuideView = [topLevelObjects objectAtIndex:0];
    self.calloutGuideView.frame = CGRectMake(0, 0, CALLOUT_GUIDE_VIEW_WIDTH, [self.calloutGuideView preferredHeight]);
    self.calloutGuideView.backgroundColor = [UIColor clearColor];
    self.calloutGuideView.headingLabel.textColor = [UIColor darkGrayColor];
    self.calloutGuideView.explanationLabel.textColor = [UIColor darkGrayColor];
    self.calloutGuideView.topSpaceConstraint.constant = 10.0;
    self.calloutGuideView.headingLabelWidthConstraint.constant = CALLOUT_GUIDE_VIEW_WIDTH - 20.0;
    self.calloutGuideView.explanationLabelWidthConstraint.constant = CALLOUT_GUIDE_VIEW_WIDTH - 20.0;
    self.calloutGuideView.labelVerticalSpaceConstraint.constant = 5.0;
    
    UITapGestureRecognizer *calloutGuideViewTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(guideViewTap:)];
    [self.calloutGuideView addGestureRecognizer:calloutGuideViewTapRecognizer];
    
    self.isCalloutGuideViewShown = NO;
    
    self.calloutView = [SMCalloutView new];
    self.calloutView.delegate = self;
    self.calloutView.presentAnimation = SMCalloutAnimationStretch;
    self.calloutView.translatesAutoresizingMaskIntoConstraints = YES;
    self.calloutView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
}

//- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController*)viewController {
//    if (viewController == self.currentController) {
//        return;
//    }
//    self.currentController = viewController;
//    
//    if (viewController && [viewController conformsToProtocol:@protocol(TabSelectedListener)]) {
//        id<TabSelectedListener> tabSelectedController = (id<TabSelectedListener>)viewController;
//        [tabSelectedController tabSelected];
//    }
//}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)guideViewTap:(UITapGestureRecognizer *)recognizer {
    [self hideCalloutGuideView:YES];
}

- (void)dismissOverlayView {
    [self hideCalloutGuideView:YES];
}

- (BOOL)isShowingGuideView {
    return self.isCalloutGuideViewShown;
}

- (void)showCalloutGuideView:(NSString *)headingText
             explanationText:(NSString *)explanationText
              customPosition:(CGRect)rect
                   withArrow:(BOOL)withArrow
                      inView:(UIView *)inView {
    if (self.isCalloutGuideViewShown) {
        [self hideCalloutGuideView:NO];
    }
    
    self.calloutGuideView.headingLabel.text = headingText;
    self.calloutGuideView.explanationLabel.text = explanationText;
    
    CGFloat preferredHeight = [self.calloutGuideView preferredHeight];
    
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CALLOUT_GUIDE_VIEW_WIDTH, preferredHeight)];
    self.calloutGuideView.frame = CGRectMake(0, 0, CALLOUT_GUIDE_VIEW_WIDTH, preferredHeight);
    [containerView addSubview:self.calloutGuideView];
    
    self.calloutView.contentView = containerView;
    self.calloutView.backgroundView = withArrow ? [CustomSMCalloutDrawnBackgroundView view] : [CustomSMCalloutDrawnBackgroundView viewWithNoArrow];
    
    SMCalloutArrowDirection arrowDirection = SMCalloutArrowDirectionDown;
    arrowDirection = SMCalloutArrowDirectionAny;
    
    if (!inView) {
        inView = self.view;

        CGFloat overlayDimmingViewHeight = inView.bounds.size.height;
        CGRect overlayDimmingViewRect = CGRectMake(0, 0, inView.bounds.size.width, overlayDimmingViewHeight);
        
        self.overlayDimmingView = [[DismissOnTouchUIView alloc] initWithFrame:overlayDimmingViewRect];
        self.overlayDimmingView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.0];
        self.overlayDimmingView.translatesAutoresizingMaskIntoConstraints = YES;
        self.overlayDimmingView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [inView addSubview:self.overlayDimmingView];
        self.overlayDimmingView.delegate = self;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.overlayDimmingView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.3];
        } completion:nil];
    }
    
    [self.calloutView presentCalloutFromRect:rect
                                      inView:inView
                           constrainedToView:inView
                    permittedArrowDirections:arrowDirection
                                    animated:YES];
    
    self.isCalloutGuideViewShown = YES;
}

- (void)hideCalloutGuideView:(BOOL)animated {
    self.isCalloutGuideViewShown = NO;
    
    if (self.calloutView.window) {
        [self.calloutView dismissCalloutAnimated:animated];
    }
    
    if (self.overlayDimmingView) {
        self.overlayDimmingView.delegate = nil;
        if (animated) {
            [UIView animateWithDuration:0.3 animations:^{
                self.overlayDimmingView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.0];
            } completion:^(BOOL finished) {
                [self.overlayDimmingView removeFromSuperview];
                self.overlayDimmingView = nil;
            }];
        }
        else {
            [self.overlayDimmingView removeFromSuperview];
            self.overlayDimmingView = nil;
        }
    }
}

- (void)calloutViewDidDisappear:(SMCalloutView *)calloutView {
    UIViewController *viewController = self.selectedViewController;
    if ([viewController conformsToProtocol:@protocol(GuideViewDismissedListener)]) {
        id<GuideViewDismissedListener> guideViewController = (id<GuideViewDismissedListener>)viewController;
        [guideViewController guideViewDismissed];
    }
}

@end
