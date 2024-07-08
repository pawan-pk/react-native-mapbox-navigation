#ifdef RCT_NEW_ARCH_ENABLED
#import "MapboxNavigationView.h"

#import <react/renderer/components/RNMapboxNavigationViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNMapboxNavigationViewSpec/EventEmitters.h>
#import <react/renderer/components/RNMapboxNavigationViewSpec/Props.h>
#import <react/renderer/components/RNMapboxNavigationViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import "Utils.h"

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

    if (oldViewProps.color != newViewProps.color) {
        NSString * colorToConvert = [[NSString alloc] initWithUTF8String: newViewProps.color.c_str()];
        [_view setBackgroundColor: [Utils hexStringToColor:colorToConvert]];
    }

    [super updateProps:props oldProps:oldProps];
}

Class<RCTComponentViewProtocol> MapboxNavigationViewCls(void)
{
    return MapboxNavigationView.class;
}

@end
#endif
