package ru.normaryadom.common.ratelimit

import java.net.Inet6Address
import java.net.InetAddress
import java.net.UnknownHostException

object ClientKey {
    private const val IPV6_PREFIX_BYTES = 8
    private val literal = Regex("^[0-9.]+$|^[0-9a-fA-F.]*:[0-9a-fA-F:.]*$")

    fun of(remoteAddress: String): String =
        when (val address = remoteAddress.takeIf { it.matches(literal) }?.let(::parse)) {
            null -> remoteAddress
            is Inet6Address -> network(address)
            else -> address.hostAddress
        }

    private fun parse(literal: String): InetAddress? =
        try {
            InetAddress.getByName(literal)
        } catch (ignored: UnknownHostException) {
            null
        }

    private fun network(address: Inet6Address): String {
        val bytes = address.address
        val prefix = bytes.copyOf(IPV6_PREFIX_BYTES) + ByteArray(bytes.size - IPV6_PREFIX_BYTES)
        return InetAddress.getByAddress(prefix).hostAddress + "/64"
    }
}
