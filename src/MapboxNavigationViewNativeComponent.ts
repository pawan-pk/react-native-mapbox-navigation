import type { HostComponent, ViewProps } from 'react-native';

import type {
  DirectEventHandler,
  Double,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

type NativeCoordinate = number[];

// Event payloads must be declared INSIDE the codegen spec — under the New
// Architecture the Fabric view config (which event props exist at all) is
// generated from this interface. The previous shape declared the events only
// via an `as HostComponent<NativeProps & NativeEventsProps>` cast, so Fabric
// registered ZERO events and every callback (onCancelNavigation, onArrive,
// onError, ...) was silently dropped on New-Arch apps.
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
  // Both platforms always send coordinates (Android falls back to 0.0).
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

export default codegenNativeComponent<NativeProps>(
  'MapboxNavigationView'
) as HostComponent<NativeProps>;
