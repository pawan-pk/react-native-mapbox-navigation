"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = exports.MapboxOffline = void 0;
var _reactNative = require("react-native");
var _MapboxNavigation = _interopRequireDefault(require("./MapboxNavigation.cjs"));
var _NativeMapboxNavigationOffline = _interopRequireDefault(require("./NativeMapboxNavigationOffline.cjs"));
function _interopRequireDefault(e) { return e && e.__esModule ? e : { default: e }; }
var _default = exports.default = _MapboxNavigation.default;
// Native event name for download progress (must match the constant the iOS /
// Android module emits on).
const PROGRESS_EVENT = 'MapboxNavigationOffline.onRegionDownloadProgress';

// Lazily-constructed so merely importing the view component doesn't spin up the
// emitter. The native module ships in the same fork build, so it resolves at
// runtime on iOS/Android. (Web never imports this file — the app's navOffline
// web stub is used instead.)
let progressEmitter;
function getProgressEmitter() {
  if (!progressEmitter) {
    progressEmitter = new _reactNative.NativeEventEmitter(_NativeMapboxNavigationOffline.default);
  }
  return progressEmitter;
}

/**
 * Typed facade over the MapboxNavigationOffline TurboModule. Region downloads
 * land in the shared default TileStore the nav on-board router reads, so a
 * downloaded corridor enables offline rerouting (see PLAN-mapbox-offline-nav.md).
 */
const MapboxOffline = exports.MapboxOffline = {
  /** Download a route-corridor region; resolves the regionId on completion. */
  downloadRegion(options) {
    return _NativeMapboxNavigationOffline.default.downloadRegion(options);
  },
  /** List downloaded regions. */
  listRegions() {
    return _NativeMapboxNavigationOffline.default.listRegions();
  },
  /** Remove a downloaded region (tiles + style pack) by id. */
  removeRegion(regionId) {
    return _NativeMapboxNavigationOffline.default.removeRegion(regionId);
  },
  /** Remove every downloaded region. */
  clearAll() {
    return _NativeMapboxNavigationOffline.default.clearAllRegions();
  },
  /**
   * Subscribe to download progress. Returns a handle whose `remove()` ends the
   * subscription — call it in an effect cleanup.
   */
  onRegionDownloadProgress(listener) {
    const subscription = getProgressEmitter().addListener(PROGRESS_EVENT, listener);
    return {
      remove: () => subscription.remove()
    };
  }
};
//# sourceMappingURL=index.cjs.map