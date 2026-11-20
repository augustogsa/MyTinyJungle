//
//  GADSqueezebackAdDelegate_Beta.h
//  Google Mobile Ads SDK
//
//  Copyright 2026 Google LLC
//

#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GADAdValue.h>

@class GADSqueezebackAd;

/// Delegate protocol for receiving `GADSqueezebackAd` presentation, lifecycle, and interaction
/// events.
NS_SWIFT_NAME(SqueezebackAdDelegate)
@protocol GADSqueezebackAdDelegate <NSObject>

@optional

#pragma mark - Presentation Lifecycle

/// Called when the squeezeback ad is shown on screen.
- (void)squeezebackAdDidShow:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdDidShow(_:)) NS_SWIFT_UI_ACTOR;

/// Called when the squeezeback ad is dismissed by the user or hidden.
- (void)squeezebackAdDidHide:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdDidHide(_:)) NS_SWIFT_UI_ACTOR;

/// Called when the squeezeback ad fails to show on screen.
- (void)squeezebackAdDidFailToShow:(nonnull GADSqueezebackAd *)squeezebackAd
                         withError:(nonnull NSError *)error
    NS_SWIFT_NAME(squeezebackAdDidFailToShow(_:error:)) NS_SWIFT_UI_ACTOR;

#pragma mark - Ad Lifecycle Events

/// Called when a click is recorded for a squeezeback ad.
- (void)squeezebackAdDidRecordClick:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdDidRecordClick(_:)) NS_SWIFT_UI_ACTOR;

/// Called when an impression is recorded for a Squeezeback ad.
- (void)squeezebackAdDidRecordImpression:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdDidRecordImpression(_:)) NS_SWIFT_UI_ACTOR;

/// Called when the squeezeback ad is estimated to have earned money.
- (void)squeezebackAd:(nonnull GADSqueezebackAd *)squeezebackAd
    didRecordPaidEventWithAdValue:(nonnull GADAdValue *)value
    NS_SWIFT_NAME(squeezebackAd(_:didRecordPaidEventWith:)) NS_SWIFT_UI_ACTOR;

#pragma mark - Click-Time Lifecycle Notifications

/// Called when the squeezeback ad opens a view that covers the entire screen.
- (void)squeezebackAdWillPresentScreen:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdWillPresentScreen(_:)) NS_SWIFT_UI_ACTOR;

/// Called when the full-screen view opened from the squeezeback ad will be closed.
- (void)squeezebackAdWillDismissScreen:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdWillDismissScreen(_:)) NS_SWIFT_UI_ACTOR;

/// Called when the full-screen view opened from the squeezeback ad is closed.
- (void)squeezebackAdDidDismissScreen:(nonnull GADSqueezebackAd *)squeezebackAd
    NS_SWIFT_NAME(squeezebackAdDidDismissScreen(_:)) NS_SWIFT_UI_ACTOR;

@end
