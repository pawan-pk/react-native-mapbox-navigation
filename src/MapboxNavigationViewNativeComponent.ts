import type { ViewProps } from 'react-native';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

type NativeCoordinate = number[];
interface NativeProps extends ViewProps {
  origin: NativeCoordinate;
  destination: NativeCoordinate;
  shouldSimulateRoute?: boolean;
  showsEndOfRouteFeedback?: boolean;
  mute?: boolean;
}

export default codegenNativeComponent<NativeProps>('MapboxNavigationView');
