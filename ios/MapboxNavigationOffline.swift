import Foundation
import CoreLocation
import MapboxDirections
import MapboxMaps
import MapboxNavigationCore

// MapboxNavigationOffline — imperative offline tile-region management (iOS).
//
// Mirrors the Android MapboxNavigationOfflineModule and the official
// mapbox-navigation-ios Offline-Regions.swift example: download a per-route
// CORRIDOR (maps tileset + navigation tileset + style pack) into the TileStore
// the navigator uses, so navigation reroutes locally with no connectivity.
//
// Classic RCTEventEmitter module (RCT_EXTERN_MODULE in the .m), resolved via the
// host app's New-Arch legacy interop — same pattern as the fork's view manager.
//
// Note: Turf geometry types (Polygon, MultiPolygon, Geometry) and the
// `coordinate(at:facing:)` helper come from MapboxMaps' re-export of Turf
// (as in the official example). If a build can't find them, add `import Turf`.
@objc(MapboxNavigationOffline)
class MapboxNavigationOffline: RCTEventEmitter {

  private static let progressEvent = "MapboxNavigationOffline.onRegionDownloadProgress"
  private var hasListeners = false

  // Offline-capable provider. CoreConfig defaults already give .hybrid routing +
  // reroute detection; tilestoreConfig .default shares the one default TileStore
  // with @rnmapbox/maps and the nav view's on-board router, so downloaded tiles
  // are found at navigation time. Stated explicitly to pin the offline intent.
  private lazy var provider: MapboxNavigationProvider = {
    let coreConfig = CoreConfig(
      routingConfig: RoutingConfig(
        rerouteConfig: RerouteConfig(detectsReroute: true),
        routingProviderSource: .hybrid,
        prefersOnlineRoute: true
      ),
      predictiveCacheConfig: PredictiveCacheConfig(),
      tilestoreConfig: .default
    )
    return MapboxNavigationProvider(coreConfig: coreConfig)
  }()

  // The TileStore the navigator reads — obtained THROUGH the provider config
  // (not TileStore.default directly) so nav + maps tiles share one store.
  private var tileStore: TileStore {
    provider.coreConfig.tilestoreConfig.navigatorLocation.tileStore
  }

  override static func requiresMainQueueSetup() -> Bool { true }
  override func supportedEvents() -> [String] { [Self.progressEvent] }
  override func startObserving() { hasListeners = true }
  override func stopObserving() { hasListeners = false }

  // MARK: - downloadRegion

  @objc(downloadRegion:resolver:rejecter:)
  func downloadRegion(
    _ options: NSDictionary,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    guard let regionId = options["regionId"] as? String, !regionId.isEmpty else {
      rejecter("ERR_INVALID_ARGS", "regionId is required", nil)
      return
    }
    let coordinates = Self.parseCoordinates(options["coordinates"])
    guard coordinates.count >= 2 else {
      rejecter("ERR_INVALID_ARGS", "coordinates must contain at least origin and destination", nil)
      return
    }
    let bufferMeters = (options["bufferMeters"] as? NSNumber)?.doubleValue ?? 2000
    let minZoom = UInt8((options["minZoom"] as? NSNumber)?.intValue ?? 0)
    let maxZoom = UInt8((options["maxZoom"] as? NSNumber)?.intValue ?? 16)
    let styleURI: StyleURI = {
      if let raw = options["styleUrl"] as? String, let uri = StyleURI(rawValue: raw) { return uri }
      return .streets
    }()

    // MapboxNavigationProvider / route calc must run on the main thread.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let routeOptions = NavigationRouteOptions(coordinates: coordinates)
      Task { [weak self] in
        guard let self else { return }
        switch await self.provider.mapboxNavigation.routingProvider()
          .calculateRoutes(options: routeOptions).result {
        case .failure(let error):
          rejecter("ERR_ROUTE", "Failed to compute route for corridor: \(error.localizedDescription)", error)
        case .success(let routes):
          guard let line = routes.mainRoute.route.shape?.coordinates, line.count >= 2 else {
            rejecter("ERR_ROUTE", "route had no geometry", nil)
            return
          }
          self.downloadTiles(
            regionId: regionId,
            line: line,
            bufferMeters: bufferMeters,
            styleURI: styleURI,
            minZoom: minZoom,
            maxZoom: maxZoom,
            resolver: resolver,
            rejecter: rejecter
          )
        }
      }
    }
  }

  private func downloadTiles(
    regionId: String,
    line: [CLLocationCoordinate2D],
    bufferMeters: Double,
    styleURI: StyleURI,
    minZoom: UInt8,
    maxZoom: UInt8,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    let geometry = Self.buildCorridor(line: line, bufferMeters: bufferMeters)
    let offlineManager = OfflineManager()

    // Basemap tiles + style pack (so the map renders offline) and nav tiles (reroute).
    let mapsDescriptor = offlineManager.createTilesetDescriptor(
      for: TilesetDescriptorOptions(styleURI: styleURI, zoomRange: minZoom...maxZoom, tilesets: nil)
    )
    let navDescriptor = provider.getLatestNavigationTilesetDescriptor()

    guard let stylePackOptions = StylePackLoadOptions(
      glyphsRasterizationMode: nil,
      metadata: ["route": regionId]
    ) else {
      rejecter("ERR_DOWNLOAD", "invalid style pack options", nil)
      return
    }

    // Style pack first (style.json + glyphs/sprites), then the tile region.
    _ = offlineManager.loadStylePack(for: styleURI, loadOptions: stylePackOptions) { [weak self] stylePackResult in
      guard let self else { return }
      switch stylePackResult {
      case .failure(let error):
        self.emitProgress(regionId: regionId, percentage: 0, downloaded: 0, required: 0,
                          completed: false, failed: true, error: error.localizedDescription)
        DispatchQueue.main.async { rejecter("ERR_DOWNLOAD", "Style pack failed: \(error.localizedDescription)", error) }
      case .success:
        guard let loadOptions = TileRegionLoadOptions(
          geometry: geometry,
          descriptors: [mapsDescriptor, navDescriptor],
          metadata: ["route": regionId],
          acceptExpired: true,
          networkRestriction: .none
        ) else {
          DispatchQueue.main.async { rejecter("ERR_DOWNLOAD", "invalid tile region options", nil) }
          return
        }
        _ = self.tileStore.loadTileRegion(
          forId: regionId,
          loadOptions: loadOptions,
          progress: { [weak self] progress in
            guard let self else { return }
            let required = progress.requiredResourceCount
            let completed = progress.completedResourceCount
            let pct = required > 0 ? (Double(completed) / Double(required)) * 100.0 : 0
            self.emitProgress(regionId: regionId, percentage: pct, downloaded: completed,
                              required: required, completed: false, failed: false, error: nil)
          },
          completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
              self.emitProgress(regionId: regionId, percentage: 0, downloaded: 0, required: 0,
                                completed: false, failed: true, error: error.localizedDescription)
              DispatchQueue.main.async { rejecter("ERR_DOWNLOAD", "Tile region failed: \(error.localizedDescription)", error) }
            case .success:
              self.emitProgress(regionId: regionId, percentage: 100, downloaded: 0, required: 0,
                                completed: true, failed: false, error: nil)
              DispatchQueue.main.async { resolver(regionId) }
            }
          }
        )
      }
    }
  }

  // MARK: - list / remove / clear

  @objc(listRegions:rejecter:)
  func listRegions(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    tileStore.allTileRegions { result in
      switch result {
      case .failure(let error):
        rejecter("ERR_LIST", "Failed to list regions: \(error.localizedDescription)", error)
      case .success(let regions):
        let out: [[String: Any]] = regions.map { region in
          let required = region.requiredResourceCount
          let completed = region.completedResourceCount
          let pct = required > 0 ? (Double(completed) / Double(required)) * 100.0 : 0
          return [
            "regionId": region.id,
            "percentage": pct,
            "requiredBytes": Double(required),
            "downloadedBytes": Double(completed),
            "status": (required > 0 && completed >= required) ? "complete" : "downloading",
          ]
        }
        resolver(out)
      }
    }
  }

  @objc(removeRegion:resolver:rejecter:)
  func removeRegion(
    _ regionId: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    tileStore.removeTileRegion(forId: regionId)
    resolver(nil)
  }

  @objc(clearAllRegions:rejecter:)
  func clearAllRegions(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    tileStore.allTileRegions { [weak self] result in
      guard let self else { return }
      if case .success(let regions) = result {
        for region in regions { self.tileStore.removeTileRegion(forId: region.id) }
      }
      resolver(nil)
    }
  }

  // MARK: - helpers

  private func emitProgress(
    regionId: String,
    percentage: Double,
    downloaded: UInt64,
    required: UInt64,
    completed: Bool,
    failed: Bool,
    error: String?
  ) {
    guard hasListeners else { return }
    var body: [String: Any] = [
      "regionId": regionId,
      "percentage": percentage,
      "downloadedBytes": Double(downloaded),
      "requiredBytes": Double(required),
      "completed": completed,
      "failed": failed,
    ]
    if let error { body["error"] = error }
    sendEvent(withName: Self.progressEvent, body: body)
  }

  /// Corridor as a MultiPolygon of circles sampled along the route line. Each
  /// circle is individually valid and overlaps are fine for tile selection, so
  /// this avoids the self-intersection of naive polyline offsetting (mirrors the
  /// Android module).
  private static func buildCorridor(line: [CLLocationCoordinate2D], bufferMeters: Double) -> Geometry {
    let step = max(bufferMeters, 250)
    var centers: [CLLocationCoordinate2D] = []
    for index in 0..<(line.count - 1) {
      let start = line[index]
      let end = line[index + 1]
      centers.append(start)
      let segmentMeters = CLLocation(latitude: start.latitude, longitude: start.longitude)
        .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
      if segmentMeters > step {
        let count = Int(segmentMeters / step)
        if count > 0 {
          for k in 1...count {
            let t = Double(k) / Double(count + 1)
            centers.append(CLLocationCoordinate2D(
              latitude: start.latitude + (end.latitude - start.latitude) * t,
              longitude: start.longitude + (end.longitude - start.longitude) * t
            ))
          }
        }
      }
    }
    if let last = line.last { centers.append(last) }
    let polygons = centers.map { circlePolygon(center: $0, radiusMeters: bufferMeters) }
    return MultiPolygon(polygons).geometry
  }

  private static func circlePolygon(
    center: CLLocationCoordinate2D,
    radiusMeters: Double,
    steps: Int = 18
  ) -> Polygon {
    var ring: [CLLocationCoordinate2D] = []
    for step in 0..<steps {
      let bearing = (360.0 / Double(steps)) * Double(step)
      ring.append(center.coordinate(at: radiusMeters, facing: bearing))
    }
    if let first = ring.first { ring.append(first) } // close the ring
    return Polygon([ring])
  }

  private static func parseCoordinates(_ value: Any?) -> [CLLocationCoordinate2D] {
    guard let pairs = value as? [[NSNumber]] else { return [] }
    return pairs.compactMap { pair in
      guard pair.count >= 2 else { return nil }
      // [lng, lat]
      return CLLocationCoordinate2D(latitude: pair[1].doubleValue, longitude: pair[0].doubleValue)
    }
  }
}
