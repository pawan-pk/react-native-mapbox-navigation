package com.mapboxnavigation

import android.util.Log
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.mapbox.geojson.Point
import com.mapboxnavigation.events.ArriveEvent
import com.mapboxnavigation.events.CancelNavigationEvent
import com.mapboxnavigation.events.ErrorEvent
import com.mapboxnavigation.events.LocationChangeEvent
import com.mapboxnavigation.events.RouteProgressChangeEvent

@ReactModule(name = MapboxNavigationViewManager.NAME)
class MapboxNavigationViewManager :
  MapboxNavigationViewManagerSpec<MapboxNavigationView>() {
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

  @ReactProp(name = "hideStatusView")
  override fun setHideStatusView(view: MapboxNavigationView?, value: Boolean) {
    Log.d("[iOS only]", "Hide status of bar on navigation.")
  }

  @ReactProp(name = "showsEndOfRouteFeedback")
  override fun setShowsEndOfRouteFeedback(view: MapboxNavigationView?, value: Boolean) {
    Log.d("[iOS only]", "To showsEndOfRouteFeedback.")
  }

  @ReactProp(name = "shouldSimulateRoute")
  override fun setShouldSimulateRoute(view: MapboxNavigationView?, value: Boolean) {
    Log.d("[iOS only]", "Location simulation for debug.")
  }

  @ReactProp(name = "showCancelButton")
  override fun setShowCancelButton(view: MapboxNavigationView?, value: Boolean) {
    view?.setShowCancelButton(value)
  }

  @ReactProp(name = "language")
  override fun setLanguage(view: MapboxNavigationView?, value: String?) {
    if (value !== null) {
      view?.setLocal(value)
    }
  }

  @ReactProp(name = "destination")
  override fun setDestination(view: MapboxNavigationView?, value: ReadableMap?) {
    if (value == null) {
      view?.setDestination(null)
      return
    }
    val latitude = value.getDouble("latitude")
    val longitude = value.getDouble("longitude")

    view?.setDestination(Point.fromLngLat(longitude, latitude))
  }

  @ReactProp(name = "destinationTitle")
  override fun setDestinationTitle(view: MapboxNavigationView?, value: String?) {
    if (value != null) {
      view?.setDestinationTitle(value)
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

  @ReactProp(name = "startOrigin")
  override fun setStartOrigin(view: MapboxNavigationView?, value: ReadableMap?) {
    if (value == null) {
      view?.setStartOrigin(null)
      return
    }
    val latitude = value.getDouble("latitude")
    val longitude = value.getDouble("longitude")

    view?.setStartOrigin(Point.fromLngLat(longitude, latitude))
  }

  @ReactProp(name = "distanceUnit")
  override fun setDistanceUnit(view: MapboxNavigationView?, value: String?) {
    if (value != null)  {
      view?.setDirectionUnit(value)
    }
  }

  @ReactProp(name = "mute")
  override fun setMute(view: MapboxNavigationView?, value: Boolean) {
    view?.setMute(value)
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> {
    return mutableMapOf(
      ArriveEvent.EVENT_NAME to mapOf("registrationName" to "onArrive"),
      CancelNavigationEvent.EVENT_NAME to mapOf("registrationName" to "onCancelNavigation"),
      ErrorEvent.EVENT_NAME to mapOf("registrationName" to "onError"),
      LocationChangeEvent.EVENT_NAME to mapOf("registrationName" to "onLocationChange"),
      RouteProgressChangeEvent.EVENT_NAME to mapOf("registrationName" to "onRouteProgressChange")
    )
  }

  companion object {
    const val NAME = "MapboxNavigationView"
  }
}
