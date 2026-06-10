import type { HostComponent, ViewProps } from 'react-native';
import type { DirectEventHandler, Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';
type NativeCoordinate = number[];
type NativeLocationEvent = Readonly<{
    latitude: Double;
    longitude: Double;
    heading: Double;
    accuracy: Double;
}>;
type NativeRouteProgressEvent = Readonly<{
    distanceTraveled: Double;
    durationRemaining: Double;
    fractionTraveled: Double;
    distanceRemaining: Double;
}>;
type NativeMessageEvent = Readonly<{
    message?: string;
}>;
type NativeArriveEvent = Readonly<{
    latitude: Double;
    longitude: Double;
    /** Waypoint name (iOS). */
    name?: string;
    /** Leg/waypoint index (Android). */
    index?: Int32;
}>;
interface NativeProps extends ViewProps {
    mute?: boolean;
    separateLegs?: boolean;
    distanceUnit?: string;
    startOrigin: NativeCoordinate;
    waypoints?: {
        latitude: Double;
        longitude: Double;
        name?: string;
        separatesLegs?: boolean;
    }[];
    destinationTitle?: string;
    destination: NativeCoordinate;
    language?: string;
    showCancelButton?: boolean;
    shouldSimulateRoute?: boolean;
    showsEndOfRouteFeedback?: boolean;
    hideStatusView?: boolean;
    travelMode?: string;
    /**
     * Map/UI style: 'day' | 'night' | 'auto' (SDK default — switches with time
     * of day on iOS; day style on Android).
     */
    theme?: string;
    onLocationChange?: DirectEventHandler<NativeLocationEvent>;
    onRouteProgressChange?: DirectEventHandler<NativeRouteProgressEvent>;
    onError?: DirectEventHandler<NativeMessageEvent>;
    onCancelNavigation?: DirectEventHandler<NativeMessageEvent>;
    onArrive?: DirectEventHandler<NativeArriveEvent>;
}
declare const _default: HostComponent<NativeProps>;
export default _default;
//# sourceMappingURL=MapboxNavigationViewNativeComponent.d.ts.map