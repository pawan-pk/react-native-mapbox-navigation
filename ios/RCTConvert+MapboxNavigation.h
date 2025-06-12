

#import <React/RCTConvert.h>
#import <React/RCTConvert+CoreLocation.h>

#import "MapboxWaypoint.h"

@interface RCTConvert (MapboxNavigation)

+ (MapboxWaypoint *)MapboxWaypoint:(id)json;

typedef NSArray MapboxWaypointArray;
+ (MapboxWaypointArray *)MapboxWaypointArray:(id)json;

@end
