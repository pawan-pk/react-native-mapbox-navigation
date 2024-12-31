#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import "RCTBridge.h"

@interface MapboxNavigationViewManager : RCTViewManager
@end

@implementation MapboxNavigationViewManager

RCT_EXPORT_MODULE(MapboxNavigationView)

- (UIView *)view
{
  return [[UIView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(color, NSString)

@end
