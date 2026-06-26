import { NativeModules } from 'react-native';

// Classic (legacy-interop) native module accessor for offline tile-region
// management. The fork's view manager already uses the RCT_EXTERN_MODULE /
// ReactPackage interop, which is supported under the host app's New Architecture
// — so a plain NativeModule avoids the codegen TurboModule conformance plumbing
// (notably the iOS generated-protocol step) while resolving identically at
// runtime via NativeModules + NativeEventEmitter. The typed facade is in
// index.tsx; the module speaks plain objects across the bridge.
export interface MapboxNavigationOfflineModule {
  downloadRegion(options: object): Promise<string>;
  listRegions(): Promise<object[]>;
  removeRegion(regionId: string): Promise<void>;
  clearAllRegions(): Promise<void>;
  // Present so NativeEventEmitter can manage the progress subscription.
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

const LINKING_ERROR =
  "The native module 'MapboxNavigationOffline' is not linked. Offline APIs are " +
  'native — rebuild the app (eas build / expo run) after bumping the fork; they ' +
  'cannot ship via OTA.';

const MapboxNavigationOffline: MapboxNavigationOfflineModule =
  NativeModules.MapboxNavigationOffline ??
  new Proxy({} as MapboxNavigationOfflineModule, {
    get() {
      throw new Error(LINKING_ERROR);
    },
  });

export default MapboxNavigationOffline;
