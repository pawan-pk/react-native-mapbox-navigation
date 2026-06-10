import type { HostComponent, ViewProps } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import type { NativeEventsProps } from './types';
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
    language?: string;
    showCancelButton?: boolean;
    shouldSimulateRoute?: boolean;
    showsEndOfRouteFeedback?: boolean;
    hideStatusView?: boolean;
    travelMode?: string;
}
declare const _default: HostComponent<NativeProps & NativeEventsProps>;
export default _default;
//# sourceMappingURL=MapboxNavigationViewNativeComponent.d.ts.map