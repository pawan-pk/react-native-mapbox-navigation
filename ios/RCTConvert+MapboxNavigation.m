

#import "RCTConvert+MapboxNavigation.h"

@implementation RCTConvert (MapboxNavigation)

+ (MapboxWaypoint *)MapboxWaypoint:(id)json {
    MapboxWaypoint *waypoint = [MapboxWaypoint new];
    json = [self NSDictionary:json];
    waypoint.name = json[@"name"];
    waypoint.separatesLegs = json[@"separatesLegs"] != nil ? [json[@"separatesLegs"] boolValue] : YES;
    waypoint.coordinate = (CLLocationCoordinate2D){
        [self CLLocationDegrees:json[@"latitude"]],
        [self CLLocationDegrees:json[@"longitude"]]
    };
    return waypoint;
}

RCT_ARRAY_CONVERTER(MapboxWaypoint)

@end

