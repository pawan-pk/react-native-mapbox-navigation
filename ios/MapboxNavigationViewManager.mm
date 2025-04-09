#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import "RCTBridge.h"
#import "RCTConvert+MapboxNavigation.h"

@interface MapboxNavigationViewManager : RCTViewManager
@end

@implementation MapboxNavigationViewManager

RCT_EXPORT_MODULE(MapboxNavigationView)

- (UIView *)view
{
  return [[UIView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(mute, BOOL)
RCT_EXPORT_VIEW_PROPERTY(profile, NSString)
RCT_EXPORT_VIEW_PROPERTY(mapStyle, NSString)
RCT_EXPORT_VIEW_PROPERTY(distanceUnit, NSString)
RCT_EXPORT_VIEW_PROPERTY(startOrigin, NSArray)
RCT_EXPORT_VIEW_PROPERTY(destination, NSArray)
RCT_CUSTOM_VIEW_PROPERTY(waypoints, NSArray, NSObject)
{
    MapboxWaypointArray *waypoint = [RCTConvert MapboxWaypointArray:json];
    [self performSelector:@selector(setWaypoints:waypoints:) withObject:view withObject:waypoint];
}
RCT_EXPORT_VIEW_PROPERTY(destinationTitle, NSString)
RCT_EXPORT_VIEW_PROPERTY(language, NSString)
RCT_EXPORT_VIEW_PROPERTY(showCancelButton, BOOL)
RCT_EXPORT_VIEW_PROPERTY(shouldSimulateRoute, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsEndOfRouteFeedback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(hideStatusView, BOOL)

@end
