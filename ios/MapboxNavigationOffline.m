//
//  MapboxNavigationOffline.m
//  react-native-mapbox-navigation
//
//  Imperative offline tile-region management. Classic RCTEventEmitter module
//  (resolved via the host app's New-Arch legacy interop, like the view manager).
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(MapboxNavigationOffline, RCTEventEmitter)

RCT_EXTERN_METHOD(downloadRegion:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(listRegions:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(removeRegion:(NSString *)regionId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clearAllRegions:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
