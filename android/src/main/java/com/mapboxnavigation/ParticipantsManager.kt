package com.mapboxnavigation

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableArray
import com.facebook.react.modules.core.DeviceEventManagerModule

class ParticipantsManager(private val context: ReactApplicationContext) :
        ReactContextBaseJavaModule(context) {

    companion object {
        var shared: ParticipantsManager? = null
    }

    private var participants: List<Map<String, Any>> = emptyList()

  interface ParticipantsDelegate {
    fun participantsDidUpdate(list: List<Map<String, Any>>)
  }
  var delegate: ParticipantsDelegate? = null
    init {
        shared = this
    }

    override fun getName(): String = "ParticipantsManager"

    @ReactMethod
    fun updateParticipants(list: ReadableArray) {
      val participants = mutableListOf<Map<String, Any>>()

      for (i in 0 until list.size()) {
        val map = list.getMap(i) ?: continue
        val convertedMap = map.toHashMap()
        participants.add(convertedMap)
      }

      // Now you can use 'participants' as List<Map<String, Any>>
      this.participants = participants
      delegate?.participantsDidUpdate(participants)
//      context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
//        .emit("onParticipantsUpdate", list)
    }

    fun getParticipants(): List<Map<String, Any>> = participants
}
