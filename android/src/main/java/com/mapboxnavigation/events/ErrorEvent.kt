package com.mapboxnavigation.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class ErrorEvent(
  surfaceId: Int,
  viewId: Int,
  private val message: String?,
) : Event<ErrorEvent>(surfaceId, viewId) {
  override fun getEventName() = EVENT_NAME

  // All events for a given view can be coalesced.
  override fun getCoalescingKey(): Short = 0

  override fun getEventData(): WritableMap? =
    Arguments.createMap().apply {
      putString("message", message)
    }

  companion object {
    const val EVENT_NAME = "topError"
  }
}
