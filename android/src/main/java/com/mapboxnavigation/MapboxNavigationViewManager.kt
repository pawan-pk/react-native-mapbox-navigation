package com.mapboxnavigation

import android.content.pm.PackageManager
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.mapbox.geojson.Point
import com.mapbox.maps.ResourceOptionsManager
import com.mapbox.maps.TileStoreUsageMode

@ReactModule(name = MapboxNavigationViewManager.NAME)
class MapboxNavigationViewManager(private var reactContext: ReactApplicationContext) :
  MapboxNavigationViewManagerSpec<MapboxNavigationView>() {
  private var accessToken: String? = null
  init {
    reactContext.runOnUiQueueThread {
      try {
        val app = reactContext.packageManager.getApplicationInfo(reactContext.packageName, PackageManager.GET_META_DATA)
        val bundle = app.metaData
        val accessToken = bundle.getString("MAPBOX_ACCESS_TOKEN")
        this.accessToken = accessToken
        ResourceOptionsManager.getDefault(reactContext, accessToken).update {
          tileStoreUsageMode(TileStoreUsageMode.READ_ONLY)
        }
      } catch (e: PackageManager.NameNotFoundException) {
        e.printStackTrace()
      }
    }
  }
  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): MapboxNavigationView {
    return MapboxNavigationView(context, this.accessToken)
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

  @ReactProp(name = "origin")
  override fun setOrigin(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setOrigin(null)
      return
    }
    view?.setOrigin(Point.fromLngLat(value.getDouble(0), value.getDouble(1)))
  }

  @ReactProp(name = "destination")
  override fun setDestination(view: MapboxNavigationView?, value: ReadableArray?) {
    if (value == null) {
      view?.setDestination(null)
      return
    }
    view?.setDestination(Point.fromLngLat(value.getDouble(0), value.getDouble(1)))
  }

  @ReactProp(name = "shouldSimulateRoute")
  override fun setShouldSimulateRoute(view: MapboxNavigationView?, value: Boolean) {
    view?.setShouldSimulateRoute(value)
  }

  @ReactProp(name = "showsEndOfRouteFeedback")
  override fun setShowsEndOfRouteFeedback(view: MapboxNavigationView?, value: Boolean) {
    view?.setShowsEndOfRouteFeedback(value)
  }

  @ReactProp(name = "mute")
  override fun setMute(view: MapboxNavigationView?, value: Boolean) {
    view?.setMute(value)
  }

  companion object {
    const val NAME = "MapboxNavigationView"
  }
}
