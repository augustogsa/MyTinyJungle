//
//  GADSqueezebackAdOptions_Beta.h
//  Google Mobile Ads SDK
//
//  Copyright 2026 Google LLC
//

#import <UIKit/UIKit.h>

/// Options for presenting a `GADSqueezebackAd`.
NS_SWIFT_NAME(SqueezebackAdOptions)
@interface GADSqueezebackAdOptions : NSObject

/// The fallback background color shown behind the ad content when the creative does not provide a
/// background media asset. If nil, the SDK uses a default color.
@property(nonatomic, copy, nullable) UIColor *fallbackBackgroundColor;

/// The window scene where the squeezeback ad will be presented. Defaults to nil. If nil, the SDK
/// automatically resolves the active window scene.
@property(nonatomic, weak, nullable) UIWindowScene *windowScene;

@end
