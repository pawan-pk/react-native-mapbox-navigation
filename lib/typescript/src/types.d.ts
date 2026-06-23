import type { StyleProp, ViewStyle } from 'react-native';
import type { Language } from './locals';
export type Coordinate = {
    latitude: number;
    longitude: number;
};
export type Waypoint = Coordinate & {
    name?: string;
    /**
     * Indicates whether the `onArrive` event is triggered when reaching the waypoint effectively.
     * @Default true
     */
    separatesLegs?: boolean;
};
export type WaypointEvent = Coordinate & {
    /**
     * Name of Waypoint if provided or index of legs/waypoint
     * @available iOS
     **/
    name?: string;
    /**
     * Index of legs/waypoint
     * @available Android
     **/
    index?: number;
};
export type Location = {
    latitude: number;
    longitude: number;
    heading: number;
    accuracy: number;
};
export type NativeEvent<T> = {
    nativeEvent: T;
};
export type RouteProgress = {
    distanceTraveled: number;
    durationRemaining: number;
    fractionTraveled: number;
    distanceRemaining: number;
};
export type MapboxEvent = {
    message?: string;
};
export type NativeEventsProps = {
    onLocationChange?: (event: NativeEvent<Location>) => void;
    onRouteProgressChange?: (event: NativeEvent<RouteProgress>) => void;
    onError?: (event: NativeEvent<MapboxEvent>) => void;
    onCancelNavigation?: (event: NativeEvent<MapboxEvent>) => void;
    onArrive?: (event: NativeEvent<WaypointEvent>) => void;
};
export interface MapboxNavigationProps {
    style?: StyleProp<ViewStyle>;
    mute?: boolean;
    /**
     * Whether the bottom-banner cancel (X) button is shown. Defaults to `false`
     * — the SDK's cancel button is suppressed (the ETA / distance / arrival
     * banner is kept) so a host app with its own exit control isn't duplicated.
     * Set `true` to restore the SDK's default banner with the cancel button.
     * iOS only.
     */
    showCancelButton?: boolean;
    startOrigin: Coordinate;
    waypoints?: Waypoint[];
    separateLegs?: boolean;
    destination: Coordinate & {
        title?: string;
    };
    language?: Language;
    distanceUnit?: 'metric' | 'imperial';
    /**
     * Specifies the mode of travel for navigation.
     *
     * - 'driving': Standard driving mode that does not take live traffic conditions into account.
     * - 'driving-traffic': Driving mode that considers current traffic conditions to avoid congestion.
     * - 'walking': Navigation for pedestrians.
     * - 'cycling': Navigation optimized for cyclists.
     *
     * @Default "driving-traffic"
     */
    travelMode?: 'driving' | 'driving-traffic' | 'walking' | 'cycling';
    /**
     * Map/UI style. 'day' and 'night' force the corresponding style (and follow
     * live prop changes); 'auto' (default) lets the SDK decide — on iOS it
     * switches with time of day, on Android it uses the day style.
     */
    theme?: 'day' | 'night' | 'auto';
    /**
     * App Mapbox style URI (e.g. "mapbox://styles/mapbox/light-v11") so the nav
     * map matches the app's other maps. Omitted = the SDK navigation style.
     * Also applies the app font family on iOS. Pass the URI matching the current
     * color scheme (paired with `theme`).
     */
    styleUrl?: string;
    /**
     * Font family (PostScript family name, e.g. "Rubik") for the nav UI labels.
     * Omitted = the SDK default font. The font must be registered in the host
     * app (bundled or runtime-loaded).
     * @available iOS — Android's maneuver banner uses a build-time text
     * appearance, so a runtime font name has no effect there.
     */
    fontFamily?: string;
    /**
     * Extra bottom camera inset (points on iOS / dp on Android) so the route and
     * puck stay framed above an app overlay (e.g. a bottom sheet) covering the
     * lower part of the nav view.
     * @Default 0
     */
    bottomInset?: number;
    /**
     * 3D location-puck model URI supplied by the host app — a `.glb`/`.gltf`
     * model (local or remote; the SDK fetches it directly). Rendered as a 3D
     * puck that turns with the travel course (a Wolt-style vehicle). Omitted =
     * the SDK's default 2D puck.
     */
    puckModelUri?: string;
    /**
     * Destination-marker image URI supplied by the host app (e.g. the app's donor
     * pin) so the embedded nav matches the host's other maps. Omitted = the SDK's
     * default destination marker.
     * @available iOS — Android's Drop-In UI marker customization is a follow-up.
     */
    destinationImageUri?: string;
    /**
     * Max vehicle height in METERS for truck routing. When set, the route is
     * restricted to roads with a height limit >= this value (avoids low bridges /
     * tunnels where Mapbox has the restriction data). Serialized as the Directions
     * API `max_height` parameter on the driving / driving-traffic profiles.
     * Omitted / 0 = the API default of 1.6 m (car-sized). Best-effort: coverage of
     * road restriction data varies by region.
     * @Default 0 (unset → API default 1.6 m)
     */
    vehicleMaxHeight?: number;
    /**
     * Max vehicle width in METERS for truck routing. Restricts the route to roads
     * with a width limit >= this value. Serialized as `max_width`.
     * Omitted / 0 = the API default of 1.9 m.
     * @Default 0 (unset → API default 1.9 m)
     */
    vehicleMaxWidth?: number;
    /**
     * Max vehicle weight in METRIC TONS (1000 kg) for truck routing. Restricts the
     * route to roads with a weight limit >= this value (avoids weight-restricted
     * bridges / roads). Serialized as `max_weight`.
     * Omitted / 0 = the API default of 2.5 metric tons.
     * @Default 0 (unset → API default 2.5 t)
     */
    vehicleMaxWeight?: number;
    /**
     * [iOS only]
     * @Default false
     */
    showsEndOfRouteFeedback?: boolean;
    /**
     * Whether the SDK's report-issue / feedback floating button is shown.
     * Hiding it keeps the overview, recenter and mute buttons.
     * [iOS only]
     * @Default true (SDK default)
     */
    showsReportFeedback?: boolean;
    /**
     * Hide status of bar on navigation [iOS only]
     * @Default false
     */
    hideStatusView?: boolean;
    /**
     * Location simulation for debug.
     * @Default false
     * @available iOS
     * @android Planned for next release
     */
    shouldSimulateRoute?: boolean;
    onLocationChange?: (location: Location) => void;
    onRouteProgressChange?: (progress: RouteProgress) => void;
    onError?: (error: MapboxEvent) => void;
    onCancelNavigation?: (event: MapboxEvent) => void;
    onArrive?: (point: WaypointEvent) => void;
}
//# sourceMappingURL=types.d.ts.map