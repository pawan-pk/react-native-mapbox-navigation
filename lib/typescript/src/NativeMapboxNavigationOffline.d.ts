export interface MapboxNavigationOfflineModule {
    downloadRegion(options: object): Promise<string>;
    listRegions(): Promise<object[]>;
    removeRegion(regionId: string): Promise<void>;
    clearAllRegions(): Promise<void>;
    addListener(eventName: string): void;
    removeListeners(count: number): void;
}
declare const MapboxNavigationOffline: MapboxNavigationOfflineModule;
export default MapboxNavigationOffline;
//# sourceMappingURL=NativeMapboxNavigationOffline.d.ts.map