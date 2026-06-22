//
//  MapboxNavigationViewManager.m
//  react-native-mapbox-navigation
//
//  Created by Pawan Kushwaha on 10/07/2024.
//

#import "React/RCTViewManager.h"
#import "MapboxWaypoint.h"
#import "RCTConvert+MapboxNavigation.h"

@interface RCT_EXTERN_MODULE(MapboxNavigationViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(onLocationChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRouteProgressChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onCancelNavigation, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onArrive, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(startOrigin, NSArray)
RCT_CUSTOM_VIEW_PROPERTY(waypoints, NSArray, NSObject)
{
    MapboxWaypointArray *waypoint = [RCTConvert MapboxWaypointArray:json];
    [self performSelector:@selector(setWaypoints:waypoints:) withObject:view withObject:waypoint];
}
RCT_EXPORT_VIEW_PROPERTY(destination, NSArray)
RCT_EXPORT_VIEW_PROPERTY(destinationTitle, NSString)
RCT_EXPORT_VIEW_PROPERTY(shouldSimulateRoute, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsEndOfRouteFeedback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsReportFeedback, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showCancelButton, BOOL)
RCT_EXPORT_VIEW_PROPERTY(language, NSString)
RCT_EXPORT_VIEW_PROPERTY(distanceUnit, NSString)
RCT_EXPORT_VIEW_PROPERTY(mute, BOOL)
RCT_EXPORT_VIEW_PROPERTY(travelMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(theme, NSString)
RCT_EXPORT_VIEW_PROPERTY(styleUrl, NSString)
RCT_EXPORT_VIEW_PROPERTY(fontFamily, NSString)
RCT_EXPORT_VIEW_PROPERTY(bottomInset, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(puckImage, UIImage)
RCT_EXPORT_VIEW_PROPERTY(destinationImage, UIImage)
RCT_EXPORT_VIEW_PROPERTY(vehicleMaxHeight, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(vehicleMaxWidth, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(vehicleMaxWeight, NSNumber)

@end
