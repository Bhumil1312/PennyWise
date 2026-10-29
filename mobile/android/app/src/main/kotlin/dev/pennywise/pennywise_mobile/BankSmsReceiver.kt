package dev.pennywise.pennywise_mobile

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import java.util.concurrent.Executors

class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION ||
            context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) return
        val store = BankSmsStore(context)
        if (!store.enabled) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isEmpty()) return
        val messages = parts.groupBy { it.originatingAddress.orEmpty() }.map { (sender, segments) ->
            Triple(sender, segments.joinToString("") { it.messageBody.orEmpty() }, segments.first().timestampMillis)
        }
        val pending = goAsync()
        worker.execute {
            try {
                for ((sender, body, timestamp) in messages) {
                    if (BankSmsRules.shouldCapture(sender, body, store.senders)) {
                        val receivedAt = timestamp.takeIf { it > 0 } ?: System.currentTimeMillis()
                        store.enqueue(BankSmsRules.messageId(sender, body, receivedAt), sender, body, receivedAt)
                    }
                }
            } finally { pending.finish() }
        }
    }

    companion object {
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "bank-sms-capture").apply { isDaemon = true }
        }
    }
}
