import type { StyleProp, ViewStyle } from 'react-native';

export type Coordinate = {
  latitude: number;
  longitude: number;
};

type OnLocationChangeEvent = {
  nativeEvent?: Coordinate;
};

type OnRouteProgressChangeEvent = {
  nativeEvent?: {
    distanceTraveled: number;
    durationRemaining: number;
    fractionTraveled: number;
    distanceRemaining: number;
  };
};

type OnErrorEvent = {
  nativeEvent?: {
    message?: string;
  };
};

export interface MapboxNavigationProps {
  style?: StyleProp<ViewStyle>;
  mute?: boolean;
  origin: Coordinate;
  destination: Coordinate;
  shouldSimulateRoute?: boolean;
  showsEndOfRouteFeedback?: boolean;
  onLocationChange?: (event: OnLocationChangeEvent) => void;
  onRouteProgressChange?: (event: OnRouteProgressChangeEvent) => void;
  onError?: (event: OnErrorEvent) => void;
  onCancelNavigation?: () => void;
  onArrive?: () => void;
  // hideStatusView?: boolean;
}
