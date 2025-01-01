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
    
  }
  
  if (oldViewProps.profile != newViewProps.profile) {
    
  }
  
  if (oldViewProps.mapStyle != newViewProps.mapStyle) {
    
  }
  
  if (oldViewProps.distanceUnit != newViewProps.distanceUnit) {
    
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
    
  }
  
  if (oldViewProps.language != newViewProps.language) {
    
  }
  
  if (oldViewProps.showCancelButton != newViewProps.showCancelButton) {
    
  }
  
  if (oldViewProps.shouldSimulateRoute != newViewProps.shouldSimulateRoute) {
    
  }
  
  if (oldViewProps.showsEndOfRouteFeedback != newViewProps.showsEndOfRouteFeedback) {
    
  }
  
  if (oldViewProps.hideStatusView != newViewProps.hideStatusView) {
    
  }
  
  [super updateProps:props oldProps:oldProps];
}

Class<RCTComponentViewProtocol> MapboxNavigationViewCls(void)
{
  return MapboxNavigationView.class;
}

@end
