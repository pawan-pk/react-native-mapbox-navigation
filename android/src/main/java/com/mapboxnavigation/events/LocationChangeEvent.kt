package com.mapboxnavigation.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class LocationChangeEvent(
  surfaceId: Int,
  viewId: Int,
  private val latitude: Double,
  private val longitude: Double,
  private val heading: Double,
  private val accuracy: Double,
) : Event<LocationChangeEvent>(surfaceId, viewId) {
  override fun getEventName() = EVENT_NAME

  // All events for a given view can be coalesced.
  override fun getCoalescingKey(): Short = 0

  override fun getEventData(): WritableMap? =
    Arguments.createMap().apply {
      putDouble("latitude", latitude)
      putDouble("longitude", longitude)
      putDouble("heading", heading)
      putDouble("accuracy", accuracy)
    }

  companion object {
    const val EVENT_NAME = "topLocationChange"
  }
}
