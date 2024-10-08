//
//  MapboxWaypoint.h
//  Pods
//
//  Created by Pawan Kumar Kushwaha on 21/07/24.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MapboxWaypoint : NSObject

@property (nullable, assign) NSString* name;
@property (nonatomic, assign) Boolean separatesLegs;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end
