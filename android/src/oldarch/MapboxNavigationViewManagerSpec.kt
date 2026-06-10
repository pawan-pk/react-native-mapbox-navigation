package com.mapboxnavigation

import android.view.View
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.SimpleViewManager

// Method names mirror the New Arch codegen interface (set<PropName> from the TS
// spec) so the concrete manager compiles identically under both architectures.
abstract class MapboxNavigationViewManagerSpec<T : View> : SimpleViewManager<T>() {
  abstract fun setStartOrigin(view: T?, value: ReadableArray?)
  abstract fun setDestination(view: T?, value: ReadableArray?)
  abstract fun setDestinationTitle(view: T?, value: String?)
  abstract fun setWaypoints(view: T?, value: ReadableArray?)
  abstract fun setDistanceUnit(view: T?, value: String?)
  abstract fun setLanguage(view: T?, language: String?)
  abstract fun setMute(view: T?, value: Boolean)
  abstract fun setShowCancelButton(view: T?, value: Boolean)
  abstract fun setTravelMode(view: T?, value: String?)
  abstract fun setSeparateLegs(view: T?, value: Boolean)
  abstract fun setShouldSimulateRoute(view: T?, value: Boolean)
  abstract fun setShowsEndOfRouteFeedback(view: T?, value: Boolean)
  abstract fun setHideStatusView(view: T?, value: Boolean)
  abstract fun setTheme(view: T?, value: String?)
}
