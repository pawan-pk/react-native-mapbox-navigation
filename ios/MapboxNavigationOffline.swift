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

  // The SHARED single provider — iOS allows only one active navigation core, so
  // the offline module must reuse the same instance the embedded view uses (a
  // second provider triggers the SDK's "Two simultaneous active navigation cores"
  // abort). Its config carries the offline-reroute settings + the .default
  // TileStore shared with @rnmapbox/maps. See SharedNavigationProvider.
  private var provider: MapboxNavigationProvider {
    SharedNavigationProvider.shared.get(simulated: false)
  }

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
    // The styles the app's nav map actually renders — the style pack + maps
    // tiles MUST match them or the basemap won't render offline. `styleUrls`
    // lets the app cover both its light and dark styles (the theme can flip
    // mid-trip); the styles share tile sources, so the extra cost is only the
    // second (small) style pack. Falls back to legacy `styleUrl`, then streets.
    let styleURIs: [StyleURI] = {
      var raws: [String] = []
      if let list = options["styleUrls"] as? [String] { raws = list }
      else if let single = options["styleUrl"] as? String { raws = [single] }
      var seen = Set<String>()
      let uris = raws.compactMap { raw -> StyleURI? in
        guard seen.insert(raw).inserted else { return nil }
        return StyleURI(rawValue: raw)
      }
      return uris.isEmpty ? [.streets] : uris
    }()

    // MapboxNavigationProvider / route calc must run on the main thread.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let routeOptions = NavigationRouteOptions(coordinates: coordinates)
      // Truck routing: the corridor MUST be computed with the same vehicle
      // dimensions the nav view applies to the real route (see
      // MapboxNavigationView.swift), or a dimension-forced detour can leave
      // the downloaded corridor. Same `> 0` guard + units as the view.
      if let h = (options["vehicleMaxHeight"] as? NSNumber)?.doubleValue, h > 0 {
        routeOptions.maximumHeight = Measurement(value: h, unit: .meters)
      }
      if let w = (options["vehicleMaxWidth"] as? NSNumber)?.doubleValue, w > 0 {
        routeOptions.maximumWidth = Measurement(value: w, unit: .meters)
      }
      if let wt = (options["vehicleMaxWeight"] as? NSNumber)?.doubleValue, wt > 0 {
        routeOptions.maximumWeight = Measurement(value: wt, unit: .metricTons)
      }
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
            styleURIs: styleURIs,
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
    styleURIs: [StyleURI],
    minZoom: UInt8,
    maxZoom: UInt8,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    let geometry = Self.buildCorridor(line: line, bufferMeters: bufferMeters)
    let offlineManager = OfflineManager()

    // Basemap tiles + style packs (so the map renders offline, whichever of the
    // app's styles is active) and nav tiles (reroute). One maps descriptor per
    // style; the TileStore dedupes shared source tiles across them.
    let mapsDescriptors = styleURIs.map { styleURI in
      offlineManager.createTilesetDescriptor(
        for: TilesetDescriptorOptions(styleURI: styleURI, zoomRange: minZoom...maxZoom, tilesets: nil)
      )
    }
    let navDescriptor = provider.getLatestNavigationTilesetDescriptor()

    // Style packs first (style.json + glyphs/sprites per style), then the tile
    // region. Sequential so a failure rejects once with the failing style.
    loadStylePacks(styleURIs, at: 0, offlineManager: offlineManager, regionId: regionId, rejecter: rejecter) { [weak self] in
      guard let self else { return }
      guard let loadOptions = TileRegionLoadOptions(
        geometry: geometry,
        descriptors: mapsDescriptors + [navDescriptor],
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

  /// Load the style packs for every style the app renders, one at a time; calls
  /// `onAllLoaded` after the last succeeds. A failure emits + rejects once (the
  /// tile region is never requested — a wrong-style basemap offline is exactly
  /// what the style packs exist to prevent).
  private func loadStylePacks(
    _ styleURIs: [StyleURI],
    at index: Int,
    offlineManager: OfflineManager,
    regionId: String,
    rejecter: @escaping RCTPromiseRejectBlock,
    onAllLoaded: @escaping () -> Void
  ) {
    guard index < styleURIs.count else {
      onAllLoaded()
      return
    }
    let styleURI = styleURIs[index]
    guard let stylePackOptions = StylePackLoadOptions(
      glyphsRasterizationMode: nil,
      metadata: ["route": regionId]
    ) else {
      DispatchQueue.main.async { rejecter("ERR_DOWNLOAD", "invalid style pack options", nil) }
      return
    }
    _ = offlineManager.loadStylePack(for: styleURI, loadOptions: stylePackOptions) { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        self.emitProgress(regionId: regionId, percentage: 0, downloaded: 0, required: 0,
                          completed: false, failed: true, error: error.localizedDescription)
        DispatchQueue.main.async {
          rejecter("ERR_DOWNLOAD", "Style pack failed (\(styleURI.rawValue)): \(error.localizedDescription)", error)
        }
      case .success:
        self.loadStylePacks(styleURIs, at: index + 1, offlineManager: offlineManager,
                            regionId: regionId, rejecter: rejecter, onAllLoaded: onAllLoaded)
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
