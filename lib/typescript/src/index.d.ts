import MapboxNavigation from './MapboxNavigation';
import type { OfflineRegion, OfflineRegionDownloadProgressEvent, OfflineRegionOptions } from './types';
export default MapboxNavigation;
export type { OfflineRegion, OfflineRegionOptions, OfflineRegionDownloadProgressEvent, OfflineRegionStatus, } from './types';
/**
 * Typed facade over the MapboxNavigationOffline TurboModule. Region downloads
 * land in the shared default TileStore the nav on-board router reads, so a
 * downloaded corridor enables offline rerouting (see PLAN-mapbox-offline-nav.md).
 */
export declare const MapboxOffline: {
    /** Download a route-corridor region; resolves the regionId on completion. */
    downloadRegion(options: OfflineRegionOptions): Promise<string>;
    /** List downloaded regions. */
    listRegions(): Promise<OfflineRegion[]>;
    /** Remove a downloaded region (tiles + style pack) by id. */
    removeRegion(regionId: string): Promise<void>;
    /** Remove every downloaded region. */
    clearAll(): Promise<void>;
    /**
     * Subscribe to download progress. Returns a handle whose `remove()` ends the
     * subscription — call it in an effect cleanup.
     */
    onRegionDownloadProgress(listener: (event: OfflineRegionDownloadProgressEvent) => void): {
        remove: () => void;
    };
};
//# sourceMappingURL=index.d.ts.map