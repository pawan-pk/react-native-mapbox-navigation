import { NativeEventEmitter, type NativeModule } from 'react-native';

import MapboxNavigation from './MapboxNavigation';
import NativeMapboxNavigationOffline from './NativeMapboxNavigationOffline';
import type {
  OfflineRegion,
  OfflineRegionDownloadProgressEvent,
  OfflineRegionOptions,
} from './types';

export default MapboxNavigation;

export type {
  OfflineRegion,
  OfflineRegionOptions,
  OfflineRegionDownloadProgressEvent,
  OfflineRegionStatus,
} from './types';

// Native event name for download progress (must match the constant the iOS /
// Android module emits on).
const PROGRESS_EVENT = 'MapboxNavigationOffline.onRegionDownloadProgress';

// Lazily-constructed so merely importing the view component doesn't spin up the
// emitter. The native module is registered in the same fork build, so resolution
// always succeeds at runtime on iOS/Android. (Web never imports this file — the
// app's navOffline web stub is used instead.)
let progressEmitter: NativeEventEmitter | undefined;
function getProgressEmitter(): NativeEventEmitter {
  if (!progressEmitter) {
    progressEmitter = new NativeEventEmitter(
      NativeMapboxNavigationOffline as unknown as NativeModule
    );
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
  downloadRegion(options: OfflineRegionOptions): Promise<string> {
    return NativeMapboxNavigationOffline.downloadRegion(
      options as unknown as object
    );
  },

  /** List downloaded regions. */
  listRegions(): Promise<OfflineRegion[]> {
    return NativeMapboxNavigationOffline.listRegions() as Promise<
      OfflineRegion[]
    >;
  },

  /** Remove a downloaded region (tiles + style pack) by id. */
  removeRegion(regionId: string): Promise<void> {
    return NativeMapboxNavigationOffline.removeRegion(regionId);
  },

  /** Remove every downloaded region. */
  clearAll(): Promise<void> {
    return NativeMapboxNavigationOffline.clearAllRegions();
  },

  /**
   * Subscribe to download progress. Returns a handle whose `remove()` ends the
   * subscription — call it in an effect cleanup.
   */
  onRegionDownloadProgress(
    listener: (event: OfflineRegionDownloadProgressEvent) => void
  ): { remove: () => void } {
    const subscription = getProgressEmitter().addListener(
      PROGRESS_EVENT,
      listener
    );
    return { remove: () => subscription.remove() };
  },
};
