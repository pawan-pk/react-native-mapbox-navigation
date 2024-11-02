package com.mapboxnavigation.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class ArriveEvent(
  surfaceId: Int,
  viewId: Int,
  private val name: String?,
  private val index: Int?,
  private val latitude: Double,
  private val longitude: Double
) : Event<ArriveEvent>(surfaceId, viewId) {
  override fun getEventName() = EVENT_NAME

  // All events for a given view can be coalesced.
  override fun getCoalescingKey(): Short = 0

  override fun getEventData(): WritableMap? =
    Arguments.createMap().apply {
      putString("name", name)
      index?.let {
        putInt("index", it)
      }
      putDouble("latitude", latitude)
      putDouble("longitude", longitude)
    }

  companion object {
    const val EVENT_NAME = "topArrive"
  }
}
