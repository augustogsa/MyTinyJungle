//
//  GADSqueezebackAd_Beta.h
//  Google Mobile Ads SDK
//
//  Copyright 2026 Google LLC
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <GoogleMobileAds/GADRequest.h>
#import <GoogleMobileAds/GADResponseInfo.h>
#import <GoogleMobileAds/GADSqueezebackAdDelegate_Beta.h>
#import <GoogleMobileAds/GADSqueezebackAdOptions_Beta.h>

@class GADSqueezebackAd;

/// A block to be executed when a `GADSqueezebackAd` request operation completes. On success, ad
/// is non-nil and |error| is nil. On failure, ad is nil and |error| is non-nil.
typedef void (^GADSqueezebackAdLoadCompletionHandler)(GADSqueezebackAd *_Nullable ad,
                                                      NSError *_Nullable error)
    NS_SWIFT_NAME(SqueezebackAdLoadCompletionHandler);

/// A squeezeback ad shrinks the app's content and shows an ad in the space around it.
NS_SWIFT_NAME(SqueezebackAd)
@interface GADSqueezebackAd : NSObject

/// The unique identifier assigned to a specific ad placement in an app, created on the AdMob or
/// Ad Manager UI.
@property(nonatomic, readonly, nonnull) NSString *adUnitID;

/// Information about the ad response that returned the ad.
@property(nonatomic, readonly, nonnull) GADResponseInfo *responseInfo;

/// Optional delegate to receive presentation, lifecycle, and interaction events.
@property(nonatomic, weak, nullable) id<GADSqueezebackAdDelegate> delegate;

/// Unavailable. Use +loadWithAdUnitID:request:completionHandler: instead.
- (nonnull instancetype)init NS_UNAVAILABLE;

/// Loads a squeezeback ad.
///
/// @param adUnitID An ad unit ID created in the AdMob or Ad Manager UI.
/// @param request An ad request object. If nil, a default ad request object is used.
/// @param completionHandler A handler to execute when the load operation finishes or times out.
+ (void)loadWithAdUnitID:(nonnull NSString *)adUnitID
                 request:(nullable GADRequest *)request
       completionHandler:(nonnull GADSqueezebackAdLoadCompletionHandler)completionHandler
    NS_SWIFT_NAME(load(with:request:completionHandler:))NS_SWIFT_SENDING;

/// Shows the squeezeback ad on the screen. Must be called on the main thread.
///
/// @param options The options specifying presentation behavior.
- (void)showWithOptions:(nonnull GADSqueezebackAdOptions *)options
    NS_SWIFT_NAME(show(with:)) NS_SWIFT_UI_ACTOR;

/// Hides the squeezeback ad and restores the app's content to its original size. Must be called
/// on the main thread.
- (void)hide NS_SWIFT_NAME(hide()) NS_SWIFT_UI_ACTOR;

@end
