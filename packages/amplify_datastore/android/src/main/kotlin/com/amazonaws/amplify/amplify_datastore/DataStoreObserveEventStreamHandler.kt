package com.amazonaws.amplify.amplify_datastore

import android.os.Handler
import android.os.Looper
import com.amplifyframework.datastore.appsync.SerializedModel
import io.flutter.plugin.common.EventChannel

class DataStoreObserveEventStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    override fun onListen(argunents: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
    }

    fun sendEvent(model: SerializedModel) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(model)
        }
    }

    fun endOfStream() {
        eventSink?.endOfStream()
    }

    fun error(errorCode: String, localizedMessage: String?, message: String?) {
        eventSink?.error(errorCode, localizedMessage, message)
    }

    override fun onCancel(p0: Any?) {
        eventSink = null
    }
}