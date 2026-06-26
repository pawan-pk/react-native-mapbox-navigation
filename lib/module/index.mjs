import { NativeEventEmitter } from 'react-native';
import MapboxNavigation from "./MapboxNavigation.mjs";
import NativeMapboxNavigationOffline from "./NativeMapboxNavigationOffline.mjs";
export default MapboxNavigation;
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
    progressEmitter = new NativeEventEmitter(NativeMapboxNavigationOffline);
  }
  return progressEmitter;
}

/**
 * Typed facade over the MapboxNavigationOffline TurboModule. Region downloads
 * land in the shared default TileStore the nav on-board router reads, so a
 * downloaded corridor enables offline rerouting (see PLAN-mapbox-offline-nav.md).
 */
export const MapboxOffline = {
  /** Download a route-corridor region; resolves the regionId on completion. */
  downloadRegion(options) {
    return NativeMapboxNavigationOffline.downloadRegion(options);
  },
  /** List downloaded regions. */
  listRegions() {
    return NativeMapboxNavigationOffline.listRegions();
  },
  /** Remove a downloaded region (tiles + style pack) by id. */
  removeRegion(regionId) {
    return NativeMapboxNavigationOffline.removeRegion(regionId);
  },
  /** Remove every downloaded region. */
  clearAll() {
    return NativeMapboxNavigationOffline.clearAllRegions();
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
//# sourceMappingURL=index.mjs.map