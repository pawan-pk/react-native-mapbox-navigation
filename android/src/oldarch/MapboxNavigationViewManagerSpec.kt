package com.mapboxnavigation

import android.view.View
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.SimpleViewManager
import org.intellij.lang.annotations.Language
import com.facebook.react.uimanager.annotations.ReactProp

abstract class MapboxNavigationViewManagerSpec<T : View> : SimpleViewManager<T>() {
  abstract fun setStartOrigin(view: T?, value: ReadableArray?)
  abstract fun setDestination(view: T?, value: ReadableArray?)
  abstract fun setDestinationTitle(view: T?, value: String?)
  abstract fun setWaypoints(view: T?, value: ReadableArray?)
  abstract fun setDirectionUnit(view: T?, value: String?)
  abstract fun setLocal(view: T?, language: String?)
  @ReactProp(name = "mute")
  abstract fun setMute(view: T?, value: Boolean)
  abstract fun setShowCancelButton(view: T?, value: Boolean)
  @ReactProp(name = "mapStyle")
  abstract fun setMapStyle(view: T?, value: String?)
}
