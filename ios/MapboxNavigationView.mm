#import "MapboxNavigationView.h"

#import "generated/RNMapboxNavigationViewSpec/ComponentDescriptors.h"
#import "generated/RNMapboxNavigationViewSpec/EventEmitters.h"
#import "generated/RNMapboxNavigationViewSpec/Props.h"
#import "generated/RNMapboxNavigationViewSpec/RCTComponentViewHelpers.h"

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@interface MapboxNavigationView () <RCTMapboxNavigationViewViewProtocol>

@end

@implementation MapboxNavigationView {
  UIView * _view;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<MapboxNavigationViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const MapboxNavigationViewProps>();
    _props = defaultProps;
    
    _view = [[UIView alloc] init];
    
    self.contentView = _view;
  }
  
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<MapboxNavigationViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<MapboxNavigationViewProps const>(props);
  
  if (oldViewProps.mute != newViewProps.mute) {
    RCTLog(@"Mute value: %d", newViewProps.mute);
  }
  
  if (oldViewProps.profile != newViewProps.profile) {
    NSString * profile = [[NSString alloc] initWithUTF8String: newViewProps.profile.c_str()];
    RCTLog(@"Profile value: %@", profile);
  }
  
  if (oldViewProps.mapStyle != newViewProps.mapStyle) {
    NSString * mapStyle = [[NSString alloc] initWithUTF8String: newViewProps.mapStyle.c_str()];
    RCTLog(@"MapStyle value: %@", mapStyle);
  }
  
  if (oldViewProps.distanceUnit != newViewProps.distanceUnit) {
    NSString * distanceUnit = [[NSString alloc] initWithUTF8String: newViewProps.distanceUnit.c_str()];
    RCTLog(@"DistanceUnit value: %@", distanceUnit);
  }
  
  if (oldViewProps.startOrigin.latitude != newViewProps.startOrigin.latitude
      || oldViewProps.startOrigin.longitude != newViewProps.startOrigin.longitude) {
    
  }
  
  if (oldViewProps.destination.latitude != newViewProps.destination.latitude
      || oldViewProps.destination.longitude != newViewProps.destination.longitude) {
    
  }
  
  if (oldViewProps.waypoints.size() != newViewProps.waypoints.size()) {
    
  }
  
  if (oldViewProps.destinationTitle != newViewProps.destinationTitle) {
    NSString * destinationTitle = [[NSString alloc] initWithUTF8String: newViewProps.destinationTitle.c_str()];
    RCTLog(@"DestinationTitle value: %@", destinationTitle);
  }
  
  if (oldViewProps.language != newViewProps.language) {
    NSString * language = [[NSString alloc] initWithUTF8String: newViewProps.language.c_str()];
    RCTLog(@"Language value: %@", language);
  }
  
  if (oldViewProps.showCancelButton != newViewProps.showCancelButton) {
    RCTLog(@"ShowCancelButton value: %d", newViewProps.showCancelButton);
  }
  
  if (oldViewProps.shouldSimulateRoute != newViewProps.shouldSimulateRoute) {
    RCTLog(@"ShouldSimulateRoute value: %d", newViewProps.shouldSimulateRoute);
  }
  
  if (oldViewProps.showsEndOfRouteFeedback != newViewProps.showsEndOfRouteFeedback) {
    RCTLog(@"ShowsEndOfRouteFeedback value: %d", newViewProps.showsEndOfRouteFeedback);
  }
  
  if (oldViewProps.hideStatusView != newViewProps.hideStatusView) {
    RCTLog(@"HideStatusView value: %d", newViewProps.hideStatusView);
  }

  [super updateProps:props oldProps:oldProps];
}

Class<RCTComponentViewProtocol> MapboxNavigationViewCls(void)
{
  return MapboxNavigationView.class;
}

@end
