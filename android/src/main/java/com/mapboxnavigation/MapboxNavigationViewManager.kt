package com.mapboxnavigation

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.mapbox.geojson.Point
import com.mapbox.navigation.base.internal.utils.WaypointFactory

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

  @ReactProp(name = "waypoints")
  override fun setWaypoints(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setWaypoints(listOf())
      return
    }
    val waypoints: List<Point> = value.toArrayList().mapNotNull { item ->
      val map = item as? Map<*, *>
      val latitude = map?.get("latitude") as? Double
      val longitude = map?.get("longitude") as? Double
      if (latitude != null && longitude != null) {
        Point.fromLngLat(longitude, latitude)
      } else {
        null
      }
    }
    view?.setWaypoints(waypoints)
  }

  @ReactProp(name = "language")
  override fun setLocal(view: MapboxNavigationView?, language: String?) {
    if (language !== null) {
      view?.setLocal(language)
    }
    view?.onCreate()
  }

  @ReactProp(name = "showCancelButton")
  override fun setShowCancelButton(view: MapboxNavigationView?, value: Boolean) {
    view?.setShowCancelButton(value)
  }

  @ReactProp(name = "mute")
  override fun setMute(view: MapboxNavigationView?, value: Boolean) {
    view?.setMute(value)
  }

  companion object {
    const val NAME = "MapboxNavigationView"
  }
}
