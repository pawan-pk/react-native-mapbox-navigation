import Foundation
import MapboxNavigationCore

/// iOS Nav SDK v3 allows only ONE active navigation core at a time — allocating a
/// second `MapboxNavigationProvider` logs `[BUG] Two simultaneous active
/// navigation cores` and aborts. Both the embedded view (`MapboxNavigationView`)
/// and the offline module (`MapboxNavigationOffline`) therefore route through this
/// single shared provider, so at most one core is ever created. Mirrors Android's
/// `MapboxNavigationProvider` process singleton (`create`/`retrieve`).
///
/// Main-thread only: callers (view `embed()`, the offline module after dispatching
/// to main) all touch this on the main thread, so no locking is needed.
///
/// The offline-reroute config is the SDK v3 default, stated explicitly so the
/// offline intent is pinned and survives an SDK bump:
///   - `routingProviderSource .hybrid`: online when connected, on-board (downloaded
///     tiles) when offline; `detectsReroute` must stay true.
///   - `tilestoreConfig .default`: routing tiles use `TileStore.default` — the same
///     store `@rnmapbox/maps` uses — so downloaded corridors are usable for reroute.
///   - `predictiveCacheConfig`: warms tiles ahead of the vehicle while online.
final class SharedNavigationProvider {
  static let shared = SharedNavigationProvider()

  private var provider: MapboxNavigationProvider?

  private init() {}

  /// The single app-wide provider, created on first use. `simulated` only applies
  /// to the first creation (dev-only location simulation); later callers reuse the
  /// existing core regardless.
  func get(simulated: Bool) -> MapboxNavigationProvider {
    if let provider {
      return provider
    }
    let coreConfig = CoreConfig(
      routingConfig: RoutingConfig(
        rerouteConfig: RerouteConfig(detectsReroute: true),
        routingProviderSource: .hybrid,
        prefersOnlineRoute: true
      ),
      locationSource: simulated ? .simulation(initialLocation: nil) : .live,
      predictiveCacheConfig: PredictiveCacheConfig(),
      tilestoreConfig: .default
    )
    let created = MapboxNavigationProvider(coreConfig: coreConfig)
    provider = created
    return created
  }
}
