package dev.pennywise.pennywise_mobile

import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Locale

/** Conservative pre-filter. Dart validates monetary facts again. */
internal object BankSmsRules {
    private val senderPattern = Regex("^(?:[A-Z]{2}-)?([A-Z][A-Z0-9]{2,15})(?:-[A-Z])?$")
    private val amount = Regex("(?:INR|RS\\.?|₹)\\s*[0-9][0-9,]*(?:\\.[0-9]{1,2})?", RegexOption.IGNORE_CASE)
    private val completed = Regex("\\b(?:credited|debited|spent|withdrawn|deposited|received|paid)\\b", RegexOption.IGNORE_CASE)
    private val excluded = Regex(
        "\\b(?:otp|one[- ]time(?: password| passcode)?|verification code|failed|declined|unsuccessful|not successful|pending|requested|request received|payment request|collect request|eligible|pre[- ]approved|offer|will be|to be|scheduled|not been|not (?:credited|debited|paid))\\b",
        RegexOption.IGNORE_CASE,
    )

    fun normalizeSender(value: String): String? =
        senderPattern.matchEntire(value.trim().uppercase(Locale.ROOT))?.groupValues?.get(1)

    fun shouldCapture(sender: String, body: String, allowedSenders: Set<String>): Boolean {
        val normalized = normalizeSender(sender) ?: return false
        return normalized in allowedSenders && body.length in 1..8192 &&
            amount.containsMatchIn(body) && completed.containsMatchIn(body) && !excluded.containsMatchIn(body)
    }

    fun messageId(sender: String, body: String, timestamp: Long): String {
        val canonical = "${normalizeSender(sender) ?: sender.trim()}\u0000$timestamp\u0000${body.trim()}"
        return MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
