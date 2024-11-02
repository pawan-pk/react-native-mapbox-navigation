import type {
  DirectEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';

import type { ViewProps } from 'react-native';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export type NativeCoordinate = {
  latitude: Double;
  longitude: Double;
};

type NativeLocation = {
  latitude: Double;
  longitude: Double;
  heading: Double;
  accuracy: Double;
};

type NativeRouteProgress = {
  distanceTraveled: Double;
  durationRemaining: Double;
  fractionTraveled: Double;
  distanceRemaining: Double;
};

type NativeError = {
  message?: string;
};

export type NativeOnArrive = {
  /**
   * Name of Waypoint if provided or index of legs/waypoint
   * @available iOS
   **/
  name?: string;
  /**
   * Index of legs/waypoint
   * @available Android
   **/
  index?: Double;

  // Coordinates
  latitude: Double;
  longitude: Double;
};

interface NativeProps extends ViewProps {
  mute?: boolean;
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
  // Events
  onLocationChange: DirectEventHandler<Readonly<NativeLocation>>;
  onRouteProgressChange?: DirectEventHandler<Readonly<NativeRouteProgress>>;
  onError?: DirectEventHandler<Readonly<NativeError>>;
  onCancelNavigation?: DirectEventHandler<{}>;
  onArrive?: DirectEventHandler<Readonly<NativeOnArrive>>;
}

export default codegenNativeComponent<NativeProps>('MapboxNavigationView');
