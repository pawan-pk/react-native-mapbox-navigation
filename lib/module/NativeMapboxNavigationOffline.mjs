import { NativeModules } from 'react-native';

// Classic (legacy-interop) native module accessor for offline tile-region
// management. The fork's view manager already uses the RCT_EXTERN_MODULE /
// ReactPackage interop, which is supported under the host app's New Architecture
// — so a plain NativeModule avoids the codegen TurboModule conformance plumbing
// (notably the iOS generated-protocol step) while resolving identically at
// runtime via NativeModules + NativeEventEmitter. The typed facade is in
// index.tsx; the module speaks plain objects across the bridge.

const LINKING_ERROR = "The native module 'MapboxNavigationOffline' is not linked. Offline APIs are " + 'native — rebuild the app (eas build / expo run) after bumping the fork; they ' + 'cannot ship via OTA.';
const MapboxNavigationOffline = NativeModules.MapboxNavigationOffline ?? new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }
});
export default MapboxNavigationOffline;
//# sourceMappingURL=NativeMapboxNavigationOffline.mjs.map