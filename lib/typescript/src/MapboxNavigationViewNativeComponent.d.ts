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
    /**
     * Whether the SDK's report-issue / feedback floating button is shown.
     * Defaults to the SDK default (shown). iOS only. Hiding it leaves the
     * overview, recenter and mute buttons untouched.
     */
    showsReportFeedback?: boolean;
    hideStatusView?: boolean;
    travelMode?: string;
    /**
     * Map/UI style: 'day' | 'night' | 'auto' (SDK default — switches with time
     * of day on iOS; day style on Android).
     */
    theme?: string;
    /**
     * App Mapbox style URI (e.g. "mapbox://styles/mapbox/light-v11") so the nav
     * map matches the app's other maps. Empty/omitted = the SDK navigation style.
     * Also applies the app font family (iOS).
     */
    styleUrl?: string;
    /**
     * Font family (PostScript family name, e.g. "Rubik") for the nav UI labels.
     * Empty/omitted = the SDK default font. The font must be registered in the
     * host app. iOS only — Android's maneuver banner takes a build-time text
     * appearance, so a runtime font name has no effect there.
     */
    fontFamily?: string;
    /**
     * Extra bottom camera inset (points on iOS / dp on Android) so the route and
     * puck stay framed above an app overlay (e.g. a bottom sheet) drawn over the
     * lower part of the nav view.
     */
    bottomInset?: Double;
    /**
     * Location-puck image URI, supplied by the host app (e.g.
     * `resolveAssetSource(require('…')).uri` for a per-vehicle-type icon). Empty =
     * the SDK's default puck. Loaded natively (works with Metro-dev http URIs,
     * unlike a UIImage prop) and used as the puck's bearing image so it rotates to
     * the travel course. iOS only for now.
     */
    puckImageUri?: string;
    /**
     * Destination-marker image URI, supplied by the host app (e.g. the app's donor
     * pin) so the embedded nav matches the host's other maps. Empty = the SDK's
     * default destination marker. iOS only for now.
     */
    destinationImageUri?: string;
    /**
     * Truck routing constraints, in Mapbox Directions API units: vehicleMaxHeight
     * and vehicleMaxWidth in METERS, vehicleMaxWeight in METRIC TONS (1000 kg).
     * Omitted / 0 = the API's car-sized defaults (1.6 m / 1.9 m / 2.5 t). When
     * set, the route is restricted to roads whose posted limit is >= the value.
     */
    vehicleMaxHeight?: Double;
    vehicleMaxWidth?: Double;
    vehicleMaxWeight?: Double;
    onLocationChange?: DirectEventHandler<NativeLocationEvent>;
    onRouteProgressChange?: DirectEventHandler<NativeRouteProgressEvent>;
    onError?: DirectEventHandler<NativeMessageEvent>;
    onCancelNavigation?: DirectEventHandler<NativeMessageEvent>;
    onArrive?: DirectEventHandler<NativeArriveEvent>;
}
declare const _default: HostComponent<NativeProps>;
export default _default;
//# sourceMappingURL=MapboxNavigationViewNativeComponent.d.ts.map