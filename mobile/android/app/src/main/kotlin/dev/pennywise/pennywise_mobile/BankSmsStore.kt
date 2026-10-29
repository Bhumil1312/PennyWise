package dev.pennywise.pennywise_mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Local staging queue; plaintext SMS never goes to preferences or logs. */
internal class BankSmsStore(context: Context) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences("pennywise-sms-config", Context.MODE_PRIVATE)
    private val queueFile = AtomicFile(File(appContext.noBackupFilesDir, "bank-sms-queue-v1.enc"))

    val enabled: Boolean get() = preferences.getBoolean("enabled", false)
    val senders: Set<String> get() = preferences.getStringSet("senders", emptySet())?.toSet() ?: emptySet()

    fun configure(enabled: Boolean, senderValues: List<String>) = synchronized(lock) {
        require(senderValues.size <= 32) { "Configure at most 32 sender IDs." }
        val normalized = senderValues.map { value ->
            requireNotNull(BankSmsRules.normalizeSender(value)) { "Use bank sender IDs such as HDFCBK, not phone numbers." }
        }.toSet()
        require(!enabled || normalized.isNotEmpty()) { "Add a bank sender ID before enabling capture." }
        if (enabled) readQueue()
        check(preferences.edit().putBoolean("enabled", enabled).putStringSet("senders", normalized).commit()) { "Could not save SMS settings." }
    }

    fun pending(): List<Map<String, Any>> = synchronized(lock) {
        val messages = readQueue().getJSONArray("messages")
        (0 until messages.length()).map { index ->
            val message = messages.getJSONObject(index)
            mapOf("id" to message.getString("id"), "sender" to message.getString("sender"),
                "body" to message.getString("body"), "receivedAt" to message.getLong("receivedAt"))
        }
    }

    fun status(): Map<String, Any?> = synchronized(lock) {
        try {
            val state = readQueue()
            mapOf("enabled" to enabled, "senders" to senders.sorted(),
                "pendingCount" to state.getJSONArray("messages").length(),
                "overflowCount" to state.optLong("overflowCount", 0),
                "error" to if (preferences.getBoolean("queueWriteError", false))
                    "A bank message could not be saved. Check your bank statement for missing transactions." else null)
        } catch (_: Exception) {
            mapOf("enabled" to enabled, "senders" to senders.sorted(), "pendingCount" to 0, "overflowCount" to 0,
                "error" to "The encrypted SMS queue could not be opened. It has been preserved. Disable capture and recover the queue before continuing.")
        }
    }

    fun enqueue(id: String, sender: String, body: String, receivedAt: Long) = synchronized(lock) {
        try {
            if (!enabled || !BankSmsRules.shouldCapture(sender, body, senders)) return@synchronized
            val state = readQueue()
            val messages = state.getJSONArray("messages")
            if ((0 until messages.length()).any { messages.getJSONObject(it).getString("id") == id }) return@synchronized
            if (messages.length() >= maxMessages) {
                state.put("overflowCount", state.optLong("overflowCount", 0) + 1)
            } else {
                messages.put(JSONObject().put("id", id).put("sender", sender).put("body", body).put("receivedAt", receivedAt))
            }
            writeQueue(state)
        } catch (_: Exception) {
            preferences.edit().putBoolean("queueWriteError", true).commit()
        }
    }

    fun acknowledge(ids: Set<String>) = synchronized(lock) {
        val state = readQueue()
        val old = state.getJSONArray("messages")
        val retained = JSONArray()
        for (index in 0 until old.length()) {
            val message = old.getJSONObject(index)
            if (message.getString("id") !in ids) retained.put(message)
        }
        state.put("messages", retained)
        writeQueue(state)
    }

    /** Explicit user data deletion only. Successful reads never delete messages. */
    fun clear() = synchronized(lock) {
        queueFile.delete()
        preferences.edit().putBoolean("queueWriteError", false).commit()
    }

    private fun emptyQueue() = JSONObject().put("messages", JSONArray()).put("overflowCount", 0L)

    private fun readQueue(): JSONObject {
        if (!queueFile.baseFile.exists() && !File(queueFile.baseFile.path + ".bak").exists()) return emptyQueue()
        val bytes = queueFile.openRead().use { input ->
            require(input.available() <= maxFileBytes) { "SMS queue is too large." }
            input.readBytes()
        }
        val input = DataInputStream(ByteArrayInputStream(bytes))
        require(input.readInt() == formatVersion) { "Unsupported encrypted SMS queue version." }
        val ivSize = input.readInt()
        require(ivSize == 12) { "Invalid encrypted SMS queue nonce." }
        val iv = ByteArray(ivSize).also { input.readFully(it) }
        val encrypted = input.readBytes()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(create = false), GCMParameterSpec(128, iv))
        cipher.updateAAD(aad)
        val result = JSONObject(String(cipher.doFinal(encrypted), Charsets.UTF_8))
        require(result.getJSONArray("messages").length() <= maxMessages) { "Invalid SMS queue length." }
        return result
    }

    private fun writeQueue(state: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(create = true))
        cipher.updateAAD(aad)
        val encrypted = cipher.doFinal(state.toString().toByteArray(Charsets.UTF_8))
        val bytes = ByteArrayOutputStream().also { output ->
            DataOutputStream(output).use { data ->
                data.writeInt(formatVersion); data.writeInt(cipher.iv.size)
                data.write(cipher.iv); data.write(encrypted)
            }
        }.toByteArray()
        require(bytes.size <= maxFileBytes) { "SMS queue is too large." }
        val output = queueFile.startWrite()
        try { output.write(bytes); queueFile.finishWrite(output) }
        catch (error: Exception) { queueFile.failWrite(output); throw error }
    }

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (store.containsAlias(keyAlias)) return store.getKey(keyAlias, null) as SecretKey
        check(create && !queueFile.baseFile.exists() && !File(queueFile.baseFile.path + ".bak").exists()) { "The SMS queue key is missing. Existing messages were preserved." }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setKeySize(256).build())
        }.generateKey()
    }

    companion object {
        private val lock = Any()
        private const val keyAlias = "pennywise-bank-sms-queue-v1"
        private const val formatVersion = 1
        private const val maxMessages = 500
        private const val maxFileBytes = 8 * 1024 * 1024
        private val aad = "pennywise:bank-sms-queue:v1".toByteArray(Charsets.UTF_8)
    }
}
