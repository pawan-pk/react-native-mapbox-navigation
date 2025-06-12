import type { HostComponent, ViewProps } from 'react-native';
import { requireNativeComponent } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import type { NativeEventsProps } from './types';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

type NativeCoordinate = number[];
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
  customerLocation?: NativeCoordinate;
  language?: string;
  showCancelButton?: boolean;
  shouldSimulateRoute?: boolean;
  showsEndOfRouteFeedback?: boolean;
  hideStatusView?: boolean;
  travelMode?: string;
}

const Component = (global as any).__turboModuleProxy
  ? codegenNativeComponent<NativeProps>('MapboxNavigationView')
  : requireNativeComponent<NativeProps>('MapboxNavigationView');

export default Component as HostComponent<NativeProps & NativeEventsProps>;
