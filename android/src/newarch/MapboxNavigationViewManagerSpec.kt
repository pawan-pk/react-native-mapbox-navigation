package com.mapboxnavigation

import android.view.View

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.MapboxNavigationViewManagerDelegate
import com.facebook.react.viewmanagers.MapboxNavigationViewManagerInterface
import com.facebook.react.uimanager.annotations.ReactProp

abstract class MapboxNavigationViewManagerSpec<T : View> : SimpleViewManager<T>(), MapboxNavigationViewManagerInterface<T> {
  private val mDelegate: ViewManagerDelegate<T>

  init {
    mDelegate = MapboxNavigationViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<T>? {
    return mDelegate
  }

  @ReactProp(name = "separateLegs")
  abstract fun setSeparateLegs(view: T?, value: Boolean)

  @ReactProp(name = "mute")
  abstract fun setMute(view: T?, value: Boolean)

  @ReactProp(name = "mapStyle")
  abstract fun setMapStyle(view: T?, value: String?)
}
