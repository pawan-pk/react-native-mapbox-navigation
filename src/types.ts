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
   * When true, the posted-speed-limit sign stays visible even where Mapbox has
   * no limit data; when false it only shows where a limit is known. Current
   * speed still appears on overspeed regardless.
   * [iOS only] — Android's speed-info badge is always shown and data-driven.
   * @Default false
   */
  alwaysShowSpeedLimit?: boolean;

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

// ---------------------------------------------------------------------------
// Offline navigation (MapboxNavigationOffline TurboModule)
//
// Imperative API for downloading per-route tile-region corridors into the
// shared default TileStore so the on-board router reroutes with no network.
// A region bundles three things: the maps (basemap) tileset, the navigation
// (routing) tileset, and a style pack — see the offline plan. The native
// TurboModule speaks `Object` (codegen-legal); these types are the typed
// facade the app consumes via `MapboxOffline` in index.tsx.
// ---------------------------------------------------------------------------

export type OfflineRegionStatus =
  | 'pending'
  | 'downloading'
  | 'complete'
  | 'failed';

export interface OfflineRegionOptions {
  /** Stable id for the region (e.g. the donationId). Re-downloading reuses it. */
  regionId: string;
  /**
   * Route corridor as an ordered [lng, lat] coordinate list (origin → waypoints
   * → destination). The native side requests a Directions route through these,
   * buffers it, and downloads the resulting polygon corridor. At minimum pass
   * origin + destination.
   */
  coordinates: number[][];
  /** Optional human-readable label stored in region metadata. */
  name?: string;
  /** Corridor buffer in METERS around the route line. @Default 2000 */
  bufferMeters?: number;
  /** Min tile zoom. @Default 0 */
  minZoom?: number;
  /** Max tile zoom (street detail ≈ 16; higher balloons size). @Default 16 */
  maxZoom?: number;
  /**
   * Mapbox style URI for the basemap tiles + style pack. Omitted = the SDK
   * default (Mapbox Standard) so the downloaded basemap matches the nav map.
   */
  styleUrl?: string;
}

export interface OfflineRegion {
  regionId: string;
  name?: string;
  status: OfflineRegionStatus;
  /** Bytes downloaded so far (best-effort; may be 0 until complete). */
  downloadedBytes?: number;
  /** Total bytes required for the region (best-effort). */
  requiredBytes?: number;
  /** 0–100 completion. */
  percentage: number;
}

export interface OfflineRegionDownloadProgressEvent {
  regionId: string;
  /** 0–100. */
  percentage: number;
  downloadedBytes: number;
  requiredBytes: number;
  /** True once the region (tiles + style pack) finished. */
  completed: boolean;
  /** True if the download failed; `error` carries the message. */
  failed?: boolean;
  error?: string;
}
