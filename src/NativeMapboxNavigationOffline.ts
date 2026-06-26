import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

// MapboxNavigationOffline — imperative offline tile-region management.
//
// Codegen rules: TurboModule method signatures may only use codegen-legal types
// (string / number / boolean / Object / arrays / Promise). No unions, string
// literals, or rich generics — so options and region records cross the bridge as
// `Object` and are given real types by the facade + `./types` in index.tsx.
//
// Requires codegenConfig.type = "all" in package.json so codegen emits this
// module spec alongside the MapboxNavigationView component spec.
export interface Spec extends TurboModule {
  /**
   * Download a route-corridor region (maps tileset + navigation tileset + style
   * pack) into the shared default TileStore. `options` is an OfflineRegionOptions
   * (see ./types). Resolves the regionId once the download completes; progress is
   * streamed via the onRegionDownloadProgress event.
   */
  downloadRegion(options: Object): Promise<string>;

  /** List downloaded regions as OfflineRegion[] (see ./types). */
  listRegions(): Promise<Object[]>;

  /** Remove a downloaded region (tiles + style pack) by id. */
  removeRegion(regionId: string): Promise<void>;

  /** Remove every downloaded region. */
  clearAllRegions(): Promise<void>;

  // Required by RN codegen for event-emitting TurboModules (New Arch).
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>(
  'MapboxNavigationOffline'
);
