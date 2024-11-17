import type { StyleProp, ViewStyle } from 'react-native';

import type { Language } from './locals';
import type { MapboxMapStyle } from './styleHelper';

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

export type RouteProgress = {
  distanceTraveled: number;
  durationRemaining: number;
  fractionTraveled: number;
  distanceRemaining: number;
};

export type MapboxEvent = {
  message?: string;
};

export type RouteProfile =
  | 'driving'
  | 'walking'
  | 'cycling'
  | 'driving-traffic';

export interface MapboxNavigationProps {
  style?: StyleProp<ViewStyle>;
  mute?: boolean;
  profile?: RouteProfile;
  mapStyle?: MapboxMapStyle;
  /**
   * Override mapStyle with custom style uri or style json string
   * @Default navigation-day
   * ([official guide](https://docs.mapbox.com/android/maps/guides/styles/set-a-style/#classic-style-templates-and-custom-styles))
   */
  customStyle?: string;
  showCancelButton?: boolean;
  startOrigin: Coordinate;
  waypoints?: Waypoint[];
  destination: Coordinate & { title?: string };
  language?: Language;
  distanceUnit?: 'metric' | 'imperial';
  /**
   * [iOS only]
   * @Default false
   */
  showsEndOfRouteFeedback?: boolean;
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
