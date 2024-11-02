package com.mapboxnavigation.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class RouteProgressChangeEvent(
  surfaceId: Int,
  viewId: Int,
  private val distanceTraveled: Double,
  private val durationRemaining: Double,
  private val fractionTraveled: Double,
  private val distanceRemaining: Double
) : Event<RouteProgressChangeEvent>(surfaceId, viewId) {
  override fun getEventName() = EVENT_NAME

  // All events for a given view can be coalesced.
  override fun getCoalescingKey(): Short = 0

  override fun getEventData(): WritableMap? =
    Arguments.createMap().apply {
      putDouble("distanceTraveled", distanceTraveled)
      putDouble("durationRemaining", durationRemaining)
      putDouble("fractionTraveled", fractionTraveled)
      putDouble("distanceRemaining", distanceRemaining)
    }

  companion object {
    const val EVENT_NAME = "topRouteProgressChange"
  }
}
