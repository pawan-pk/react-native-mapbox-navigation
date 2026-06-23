package com.mapboxnavigation

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.mapbox.api.directions.v5.models.DirectionsWaypoint
import com.mapbox.geojson.Point

@ReactModule(name = MapboxNavigationViewManager.NAME)
class MapboxNavigationViewManager(private var reactContext: ReactApplicationContext): MapboxNavigationViewManagerSpec<MapboxNavigationView>() {
  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): MapboxNavigationView {
    return MapboxNavigationView(context)
  }

  override fun onDropViewInstance(view: MapboxNavigationView) {
    view.onDropViewInstance()
    super.onDropViewInstance(view)
  }

  // Called after ALL props of a transaction are applied — the only safe point
  // to start navigation. (Initializing from a prop setter raced alphabetical
  // prop order: `distanceUnit` applied before `startOrigin`/`destination`.)
  override fun onAfterUpdateTransaction(view: MapboxNavigationView) {
    super.onAfterUpdateTransaction(view)
    view.initIfReady()
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Map<String, String>> {
    return MapBuilder.of(
      "onLocationChange", MapBuilder.of("registrationName", "onLocationChange"),
      "onError", MapBuilder.of("registrationName", "onError"),
      "onCancelNavigation", MapBuilder.of("registrationName", "onCancelNavigation"),
      "onArrive", MapBuilder.of("registrationName", "onArrive"),
      "onRouteProgressChange", MapBuilder.of("registrationName", "onRouteProgressChange"),
    )
  }

  @ReactProp(name = "startOrigin")
  override fun setStartOrigin(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setStartOrigin(null)
      return
    }
    view?.setStartOrigin(Point.fromLngLat(value.getDouble(0), value.getDouble(1)))
  }

  @ReactProp(name = "destination")
  override fun setDestination(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setDestination(null)
      return
    }
    view?.setDestination(Point.fromLngLat(value.getDouble(0), value.getDouble(1)))
  }

  @ReactProp(name = "destinationTitle")
  override fun setDestinationTitle(view: MapboxNavigationView?, value: String?) {
    if (value != null) {
      view?.setDestinationTitle(value)
    }
  }

  // Codegen (New Arch) requires the method name to match the TS spec prop
  // (`set<PropName>`); the view-level method keeps its original name.
  @ReactProp(name = "distanceUnit")
  override fun setDistanceUnit(view: MapboxNavigationView?, value: String?) {
    if (value != null)  {
      view?.setDirectionUnit(value)
    }
  }

  @ReactProp(name = "waypoints")
  override fun setWaypoints(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setWaypoints(listOf())
      return
    }
    val legs = mutableListOf<WaypointLegs>()
    val waypoints: List<Point> = value.toArrayList().mapIndexedNotNull { index, item ->
      val map = item as? Map<*, *>
      val latitude = map?.get("latitude") as? Double
      val longitude = map?.get("longitude") as? Double
      val name = map?.get("name") as? String
      val separatesLegs = map?.get("separatesLegs") as? Boolean
      if (separatesLegs != false) {
        legs.add(WaypointLegs(index = index + 1, name = name ?: "waypoint-$index"))
      }
      if (latitude != null && longitude != null) {
        Point.fromLngLat(longitude, latitude)
      } else {
        null
      }
    }
    view?.setWaypointLegs(legs)
    view?.setWaypoints(waypoints)
  }

  @ReactProp(name = "language")
  override fun setLanguage(view: MapboxNavigationView?, language: String?) {
    if (language !== null) {
      view?.setLocal(language)
    }
  }

  // The following props exist in the TS spec but have no Android behavior:
  // separateLegs is expressed per-waypoint (`separatesLegs`) in setWaypoints;
  // the rest are iOS-only. Codegen still requires the overrides to exist.
  @ReactProp(name = "separateLegs")
  override fun setSeparateLegs(view: MapboxNavigationView?, value: Boolean) {
    // no-op on Android — per-waypoint `separatesLegs` drives leg splitting
  }

  @ReactProp(name = "shouldSimulateRoute")
  override fun setShouldSimulateRoute(view: MapboxNavigationView?, value: Boolean) {
    // no-op on Android — iOS-only (simulation not yet supported by the Android view)
  }

  @ReactProp(name = "showsEndOfRouteFeedback")
  override fun setShowsEndOfRouteFeedback(view: MapboxNavigationView?, value: Boolean) {
    // no-op on Android — iOS-only
  }

  @ReactProp(name = "showsReportFeedback")
  override fun setShowsReportFeedback(view: MapboxNavigationView?, value: Boolean) {
    // no-op on Android — iOS-only (Android has no report/feedback button)
  }

  @ReactProp(name = "hideStatusView")
  override fun setHideStatusView(view: MapboxNavigationView?, value: Boolean) {
    // no-op on Android — iOS-only
  }

  @ReactProp(name = "showCancelButton")
  override fun setShowCancelButton(view: MapboxNavigationView?, value: Boolean) {
    view?.setShowCancelButton(value)
  }

  @ReactProp(name = "mute")
  override fun setMute(view: MapboxNavigationView?, value: Boolean) {
    view?.setMute(value)
  }

  @ReactProp(name = "travelMode")
  override fun setTravelMode(view: MapboxNavigationView?, value: String?) {
    if (value != null)  {
      view?.setTravelMode(value)
    }
  }

  @ReactProp(name = "theme")
  override fun setTheme(view: MapboxNavigationView?, value: String?) {
    if (value != null) {
      view?.setTheme(value)
    }
  }

  @ReactProp(name = "styleUrl")
  override fun setStyleUrl(view: MapboxNavigationView?, value: String?) {
    if (value != null) {
      view?.setStyleUrl(value)
    }
  }

  @ReactProp(name = "fontFamily")
  override fun setFontFamily(view: MapboxNavigationView?, value: String?) {
    // no-op on Android — the SDK maneuver banner takes a build-time text
    // appearance (R.style.*), so a runtime font-family name can't be applied.
    // iOS-only prop; declared here because codegen requires the override.
  }

  @ReactProp(name = "bottomInset")
  override fun setBottomInset(view: MapboxNavigationView?, value: Double) {
    view?.setBottomInset(value)
  }

  @ReactProp(name = "puckModelUri")
  override fun setPuckModelUri(view: MapboxNavigationView?, value: String?) {
    view?.setPuckModelUri(value ?: "")
  }

  @ReactProp(name = "destinationImageUri")
  override fun setDestinationImageUri(view: MapboxNavigationView?, value: String?) {
    view?.setDestinationImageUri(value ?: "")
  }

  @ReactProp(name = "vehicleMaxHeight", defaultDouble = 0.0)
  override fun setVehicleMaxHeight(view: MapboxNavigationView?, value: Double) {
    view?.setVehicleMaxHeight(value)
  }

  @ReactProp(name = "vehicleMaxWidth", defaultDouble = 0.0)
  override fun setVehicleMaxWidth(view: MapboxNavigationView?, value: Double) {
    view?.setVehicleMaxWidth(value)
  }

  @ReactProp(name = "vehicleMaxWeight", defaultDouble = 0.0)
  override fun setVehicleMaxWeight(view: MapboxNavigationView?, value: Double) {
    view?.setVehicleMaxWeight(value)
  }

  companion object {
    const val NAME = "MapboxNavigationView"
  }
}
