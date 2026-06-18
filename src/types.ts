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
  showCancelButton?: boolean;
  startOrigin: Coordinate;
  waypoints?: Waypoint[];
  separateLegs?: boolean;
  destination: Coordinate & { title?: string };
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
