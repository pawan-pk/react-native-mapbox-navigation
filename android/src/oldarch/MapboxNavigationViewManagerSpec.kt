package com.mapboxnavigation

import android.view.View
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.SimpleViewManager

abstract class MapboxNavigationViewManagerSpec<T : View> : SimpleViewManager<T>() {
  abstract fun setOrigin(view: T?, value: ReadableArray?)
  abstract fun setDestination(view: T?, value: ReadableArray?)
  abstract fun setShouldSimulateRoute(view: T?, value: Boolean)
  abstract fun setShowsEndOfRouteFeedback(view: T?, value: Boolean)
  abstract fun setMute(view: T?, value: Boolean)
}
