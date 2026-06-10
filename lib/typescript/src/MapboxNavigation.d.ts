import * as React from 'react';
import type { MapboxNavigationProps } from './types';
type MapboxNavigationState = {
    prepared: boolean;
    error?: string;
};
declare class MapboxNavigation extends React.Component<MapboxNavigationProps, MapboxNavigationState> {
    constructor(props: MapboxNavigationProps);
    createState(): void;
    componentDidMount(): void;
    requestPermission(): Promise<void>;
    render(): import("react/jsx-runtime").JSX.Element;
}
export default MapboxNavigation;
//# sourceMappingURL=MapboxNavigation.d.ts.map