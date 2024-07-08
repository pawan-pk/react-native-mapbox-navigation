package com.mapboxnavigation

import android.view.View

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.MapboxNavigationViewManagerDelegate
import com.facebook.react.viewmanagers.MapboxNavigationViewManagerInterface

abstract class MapboxNavigationViewManagerSpec<T : View> : SimpleViewManager<T>(), MapboxNavigationViewManagerInterface<T> {
  private val mDelegate: ViewManagerDelegate<T>

  init {
    mDelegate = MapboxNavigationViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<T>? {
    return mDelegate
  }
}
