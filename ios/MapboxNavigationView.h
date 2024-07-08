// This guard prevent this file to be compiled in the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef MapboxNavigationViewNativeComponent_h
#define MapboxNavigationViewNativeComponent_h

NS_ASSUME_NONNULL_BEGIN

@interface MapboxNavigationView : RCTViewComponentView
@end

NS_ASSUME_NONNULL_END

#endif /* MapboxNavigationViewNativeComponent_h */
#endif /* RCT_NEW_ARCH_ENABLED */
