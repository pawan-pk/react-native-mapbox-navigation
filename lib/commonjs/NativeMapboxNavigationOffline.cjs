"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;
var _reactNative = require("react-native");
// Classic (legacy-interop) native module accessor for offline tile-region
// management. The fork's view manager already uses the RCT_EXTERN_MODULE /
// ReactPackage interop, which is supported under the host app's New Architecture
// — so a plain NativeModule avoids the codegen TurboModule conformance plumbing
// (notably the iOS generated-protocol step) while resolving identically at
// runtime via NativeModules + NativeEventEmitter. The typed facade is in
// index.tsx; the module speaks plain objects across the bridge.

const LINKING_ERROR = "The native module 'MapboxNavigationOffline' is not linked. Offline APIs are " + 'native — rebuild the app (eas build / expo run) after bumping the fork; they ' + 'cannot ship via OTA.';
const MapboxNavigationOffline = _reactNative.NativeModules.MapboxNavigationOffline ?? new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }
});
var _default = exports.default = MapboxNavigationOffline;
//# sourceMappingURL=NativeMapboxNavigationOffline.cjs.map