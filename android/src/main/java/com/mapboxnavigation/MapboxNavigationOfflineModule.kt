package com.mapboxnavigation

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.bindgen.Value
import com.mapbox.common.NetworkRestriction
import com.mapbox.common.TileRegion
import com.mapbox.common.TileRegionLoadOptions
import com.mapbox.common.TileStore
import com.mapbox.core.constants.Constants
import com.mapbox.geojson.LineString
import com.mapbox.geojson.MultiPolygon
import com.mapbox.geojson.Point
import com.mapbox.geojson.Polygon
import com.mapbox.maps.GlyphsRasterizationMode
import com.mapbox.maps.OfflineManager
import com.mapbox.maps.Style
import com.mapbox.maps.StylePackLoadOptions
import com.mapbox.maps.TilesetDescriptorOptions
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.options.RoutingTilesOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.route.NavigationRouterCallback
import com.mapbox.navigation.base.route.RouterFailure
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.MapboxNavigationProvider
import com.mapbox.turf.TurfConstants
import com.mapbox.turf.TurfMeasurement
import com.mapbox.turf.TurfTransformation

/**
 * MapboxNavigationOffline — imperative offline tile-region management.
 *
 * Downloads a per-route CORRIDOR (maps tileset + navigation tileset + style pack)
 * into the shared default TileStore (the same store the nav view's on-board router
 * reads — see MapboxNavigationView.onCreate / RoutingTilesOptions), so navigation
 * reroutes locally with no connectivity inside a downloaded region.
 *
 * Classic ReactPackage/NativeModule (resolved via the host app's New-Arch legacy
 * interop, mirroring the fork's view manager). Registered in MapboxNavigationPackage.
 */
class MapboxNavigationOfflineModule(
  private val reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = NAME

  // The shared default TileStore — same no-path default @rnmapbox/maps and the nav
  // RoutingTilesOptions use, so map tiles + routing tiles + style packs coexist.
  private val tileStore: TileStore by lazy { TileStore.create() }

  /**
   * Download a route-corridor region. options = OfflineRegionOptions:
   *   { regionId, coordinates: [[lng,lat],...], bufferMeters?, minZoom?, maxZoom?, styleUrl?, name? }
   * Resolves regionId on success; streams progress via onRegionDownloadProgress.
   */
  @ReactMethod
  fun downloadRegion(options: ReadableMap, promise: Promise) {
    val regionId = options.getString("regionId")
    if (regionId.isNullOrEmpty()) {
      promise.reject(ERR_ARGS, "regionId is required")
      return
    }
    val coordinates = parseCoordinates(options.getArray("coordinates"))
    if (coordinates.size < 2) {
      promise.reject(ERR_ARGS, "coordinates must contain at least origin and destination")
      return
    }
    val bufferMeters = if (options.hasKey("bufferMeters")) options.getDouble("bufferMeters") else 2000.0
    val minZoom = (if (options.hasKey("minZoom")) options.getInt("minZoom") else 0).toByte()
    val maxZoom = (if (options.hasKey("maxZoom")) options.getInt("maxZoom") else 16).toByte()
    // The styles the app's nav map actually renders — the style packs + maps
    // tiles MUST match them or the basemap won't render offline. `styleUrls`
    // lets the app cover both its light and dark styles (the theme can flip
    // mid-trip); the styles share tile sources, so the extra cost is only the
    // second (small) style pack. Falls back to legacy `styleUrl`, then streets
    // (matching the iOS default).
    val styleUris = parseStyleUris(options)
    // Truck routing: the corridor MUST be computed with the same vehicle
    // dimensions the nav view applies to the real route (see
    // MapboxNavigationView.findRoute), or a dimension-forced detour can leave
    // the downloaded corridor. Same `> 0` guard + units (m / metric tons).
    val maxHeight = if (options.hasKey("vehicleMaxHeight")) options.getDouble("vehicleMaxHeight") else 0.0
    val maxWidth = if (options.hasKey("vehicleMaxWidth")) options.getDouble("vehicleMaxWidth") else 0.0
    val maxWeight = if (options.hasKey("vehicleMaxWeight")) options.getDouble("vehicleMaxWeight") else 0.0

    // MapboxNavigation must be created/used on the main thread.
    UiThreadUtil.runOnUiThread {
      val mapboxNavigation = retrieveOrCreateNavigation()
      requestRoute(mapboxNavigation, coordinates, maxHeight, maxWidth, maxWeight) { routePoints, error ->
        if (routePoints == null) {
          promise.reject(ERR_ROUTE, "Failed to compute route for corridor: $error")
          return@requestRoute
        }
        val corridor = buildCorridor(routePoints, bufferMeters)
        downloadTiles(mapboxNavigation, regionId, corridor, styleUris, minZoom, maxZoom, promise)
      }
    }
  }

  @ReactMethod
  fun listRegions(promise: Promise) {
    tileStore.getAllTileRegions { expected ->
      expected.fold(
        { error -> promise.reject(ERR_LIST, "Failed to list regions: ${error.message}") },
        { regions ->
          val out: WritableArray = Arguments.createArray()
          regions.forEach { out.pushMap(regionToMap(it)) }
          promise.resolve(out)
        }
      )
    }
  }

  @ReactMethod
  fun removeRegion(regionId: String, promise: Promise) {
    // Tile region only — style packs are deliberately KEPT (matches iOS). They
    // are small (style.json + glyphs/sprites), keyed by style URI not region,
    // and shared by every corridor the app ever downloads; evicting them here
    // would force a re-download on the next head-out for no disk win.
    tileStore.removeTileRegion(regionId) {
      promise.resolve(null)
    }
  }

  @ReactMethod
  fun clearAllRegions(promise: Promise) {
    tileStore.getAllTileRegions { expected ->
      expected.fold(
        { error -> promise.reject(ERR_LIST, "Failed to enumerate regions: ${error.message}") },
        { regions ->
          regions.forEach { tileStore.removeTileRegion(it.id) }
          promise.resolve(null)
        }
      )
    }
  }

  // Required so NativeEventEmitter can attach/detach the progress listener (no-op).
  @ReactMethod
  fun addListener(eventName: String) {
    // Keep: NativeEventEmitter calls this; the bridge needs the method to exist.
  }

  @ReactMethod
  fun removeListeners(count: Double) {
    // Keep: NativeEventEmitter calls this on cleanup.
  }

  // --- internals -----------------------------------------------------------

  private fun retrieveOrCreateNavigation(): MapboxNavigation {
    return if (MapboxNavigationProvider.isCreated()) {
      MapboxNavigationProvider.retrieve()
    } else {
      // First creator must install the shared TileStore so the on-board router
      // and downloaded tiles agree (matches MapboxNavigationView.onCreate).
      MapboxNavigationProvider.create(
        NavigationOptions.Builder(reactContext)
          .routingTilesOptions(RoutingTilesOptions.Builder().tileStore(TileStore.create()).build())
          .build()
      )
    }
  }

  private fun requestRoute(
    mapboxNavigation: MapboxNavigation,
    coordinates: List<Point>,
    maxHeight: Double,
    maxWidth: Double,
    maxWeight: Double,
    callback: (routePoints: List<Point>?, error: String?) -> Unit
  ) {
    val routeOptionsBuilder = RouteOptions.builder()
      .applyDefaultNavigationOptions() // overview=full, geometries=polyline6, steps
      .coordinatesList(coordinates)
      .profile(DirectionsCriteria.PROFILE_DRIVING_TRAFFIC)
    // Mirror MapboxNavigationView.findRoute's truck dimensions so the corridor
    // follows the same route the driver is actually given.
    if (maxHeight > 0) routeOptionsBuilder.maxHeight(maxHeight)
    if (maxWidth > 0) routeOptionsBuilder.maxWidth(maxWidth)
    if (maxWeight > 0) routeOptionsBuilder.maxWeight(maxWeight)
    val routeOptions = routeOptionsBuilder.build()

    mapboxNavigation.requestRoutes(
      routeOptions,
      object : NavigationRouterCallback {
        override fun onCanceled(routeOptions: RouteOptions, routerOrigin: String) {
          callback(null, "route request canceled")
        }

        override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
          callback(null, reasons.joinToString { it.message })
        }

        override fun onRoutesReady(routes: List<NavigationRoute>, routerOrigin: String) {
          val geometry = routes.firstOrNull()?.directionsRoute?.geometry()
          if (geometry.isNullOrEmpty()) {
            callback(null, "route had no geometry")
            return
          }
          // applyDefaultNavigationOptions uses polyline6.
          callback(LineString.fromPolyline(geometry, Constants.PRECISION_6).coordinates(), null)
        }
      }
    )
  }

  /**
   * Corridor as a MultiPolygon of circles sampled every ~bufferMeters along the
   * route line. Each circle is individually valid and overlaps are fine for tile
   * selection, so this avoids the self-intersection of naive polyline offsetting.
   */
  private fun buildCorridor(routePoints: List<Point>, bufferMeters: Double): MultiPolygon {
    val radiusKm = bufferMeters / 1000.0
    val line = LineString.fromLngLats(routePoints)
    val lengthKm = TurfMeasurement.length(line, TurfConstants.UNIT_KILOMETERS)
    val stepKm = (bufferMeters / 1000.0).coerceAtLeast(0.25) // sample at ~buffer spacing
    val circles = mutableListOf<Polygon>()
    var distance = 0.0
    while (distance < lengthKm) {
      val center = TurfMeasurement.along(line, distance, TurfConstants.UNIT_KILOMETERS)
      circles.add(TurfTransformation.circle(center, radiusKm, CIRCLE_STEPS, TurfConstants.UNIT_KILOMETERS))
      distance += stepKm
    }
    // Always include the final point so the destination is covered.
    circles.add(
      TurfTransformation.circle(routePoints.last(), radiusKm, CIRCLE_STEPS, TurfConstants.UNIT_KILOMETERS)
    )
    return MultiPolygon.fromPolygons(circles)
  }

  private fun downloadTiles(
    mapboxNavigation: MapboxNavigation,
    regionId: String,
    geometry: MultiPolygon,
    styleUris: List<String>,
    minZoom: Byte,
    maxZoom: Byte,
    promise: Promise
  ) {
    val offlineManager = OfflineManager()

    // Basemap tiles + style packs so the map renders offline (whichever of the
    // app's styles is active); nav tiles for reroute. One maps descriptor per
    // style; the TileStore dedupes shared source tiles across them.
    val mapsDescriptors = styleUris.map { styleUri ->
      offlineManager.createTilesetDescriptor(
        TilesetDescriptorOptions.Builder()
          .styleURI(styleUri)
          .minZoom(minZoom)
          .maxZoom(maxZoom)
          .pixelRatio(reactContext.resources.displayMetrics.density)
          .build()
      )
    }
    val navDescriptor = mapboxNavigation.tilesetDescriptorFactory.getLatest()

    // Style packs (style.json + glyphs/sprites per style) are required for an
    // offline basemap. Sequential so a failure rejects once with the failing style.
    loadStylePacks(offlineManager, styleUris, 0, regionId, promise) {
      val regionOptions = TileRegionLoadOptions.Builder()
        .geometry(geometry)
        .descriptors(mapsDescriptors + navDescriptor)
        .acceptExpired(true)
        .networkRestriction(NetworkRestriction.NONE)
        // Metadata MUST be a JSON object, not a bare string: the TileStore is
        // shared with @rnmapbox/maps, whose offlineManager.getPacks() parses
        // every region's metadata as JSON and CRASHED the app on a bare string
        // (field UAT: region "3964"). Matches the iOS module's ["route": id].
        .metadata(Value.valueOf(hashMapOf("route" to Value.valueOf(regionId))))
        .build()

      tileStore.loadTileRegion(
        regionId,
        regionOptions,
        { progress ->
          val required = progress.requiredResourceCount
          val completedCount = progress.completedResourceCount
          val pct = if (required > 0) (completedCount.toDouble() / required.toDouble()) * 100.0 else 0.0
          emitProgress(regionId, pct, completedCount, required, completed = false, failed = false, error = null)
        }
      ) { regionResult ->
        regionResult.fold(
          { error ->
            emitProgress(regionId, 0.0, 0L, 0L, completed = false, failed = true, error = error.message)
            promise.reject(ERR_DOWNLOAD, "Tile region failed: ${error.message}")
          },
          {
            emitProgress(regionId, 100.0, 0L, 0L, completed = true, failed = false, error = null)
            promise.resolve(regionId)
          }
        )
      }
    }
  }

  /**
   * Load the style packs for every style the app renders, one at a time; runs
   * [onAllLoaded] after the last succeeds. A failure emits + rejects once (the
   * tile region is never requested — a wrong-style basemap offline is exactly
   * what the style packs exist to prevent).
   */
  private fun loadStylePacks(
    offlineManager: OfflineManager,
    styleUris: List<String>,
    index: Int,
    regionId: String,
    promise: Promise,
    onAllLoaded: () -> Unit
  ) {
    if (index >= styleUris.size) {
      onAllLoaded()
      return
    }
    val styleUri = styleUris[index]
    val stylePackOptions = StylePackLoadOptions.Builder()
      .glyphsRasterizationMode(GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY)
      // JSON-object metadata for the same shared-TileStore reason as the tile
      // region above (see that comment).
      .metadata(Value.valueOf(hashMapOf("route" to Value.valueOf(regionId))))
      .build()
    offlineManager.loadStylePack(styleUri, stylePackOptions, { /* style-pack progress */ }) { stylePackResult ->
      val stylePackError = stylePackResult.error
      if (stylePackError != null) {
        emitProgress(regionId, 0.0, 0L, 0L, completed = false, failed = true, error = stylePackError.message)
        promise.reject(ERR_DOWNLOAD, "Style pack failed ($styleUri): ${stylePackError.message}")
      } else {
        loadStylePacks(offlineManager, styleUris, index + 1, regionId, promise, onAllLoaded)
      }
    }
  }

  private fun emitProgress(
    regionId: String,
    percentage: Double,
    downloadedBytes: Long,
    requiredBytes: Long,
    completed: Boolean,
    failed: Boolean,
    error: String?
  ) {
    // Downloads outlive React instances (foreground OTA force-reload can tear
    // the instance down mid-download) — emitting into a dead instance throws.
    // iOS gets the same protection from RCTEventEmitter's hasListeners.
    if (!reactContext.hasActiveReactInstance()) return
    val event: WritableMap = Arguments.createMap()
    event.putString("regionId", regionId)
    event.putDouble("percentage", percentage)
    event.putDouble("downloadedBytes", downloadedBytes.toDouble())
    event.putDouble("requiredBytes", requiredBytes.toDouble())
    event.putBoolean("completed", completed)
    event.putBoolean("failed", failed)
    if (error != null) event.putString("error", error)
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(PROGRESS_EVENT, event)
  }

  private fun regionToMap(region: TileRegion): WritableMap {
    val map: WritableMap = Arguments.createMap()
    map.putString("regionId", region.id)
    val required = region.requiredResourceCount
    val completed = region.completedResourceCount
    val pct = if (required > 0) (completed.toDouble() / required.toDouble()) * 100.0 else 0.0
    map.putDouble("percentage", pct)
    map.putDouble("requiredBytes", required.toDouble())
    map.putDouble("downloadedBytes", completed.toDouble())
    map.putString("status", if (completed >= required && required > 0) "complete" else "downloading")
    return map
  }

  private fun parseCoordinates(array: ReadableArray?): List<Point> {
    if (array == null) return emptyList()
    val points = mutableListOf<Point>()
    for (i in 0 until array.size()) {
      val pair = array.getArray(i) ?: continue
      if (pair.size() < 2) continue
      // [lng, lat]
      points.add(Point.fromLngLat(pair.getDouble(0), pair.getDouble(1)))
    }
    return points
  }

  private fun parseStyleUris(options: ReadableMap): List<String> {
    val fromArray = options.getArray("styleUrls")?.let { array ->
      (0 until array.size()).mapNotNull { index -> array.getString(index) }
    } ?: emptyList()
    val uris = when {
      fromArray.isNotEmpty() -> fromArray
      else -> listOfNotNull(options.getString("styleUrl"))
    }.distinct().filter { it.isNotEmpty() }
    return uris.ifEmpty { listOf(Style.MAPBOX_STREETS) }
  }

  companion object {
    const val NAME = "MapboxNavigationOffline"
    private const val PROGRESS_EVENT = "MapboxNavigationOffline.onRegionDownloadProgress"
    private const val CIRCLE_STEPS = 18
    private const val ERR_ARGS = "ERR_INVALID_ARGS"
    private const val ERR_ROUTE = "ERR_ROUTE"
    private const val ERR_DOWNLOAD = "ERR_DOWNLOAD"
    private const val ERR_LIST = "ERR_LIST"
  }
}
