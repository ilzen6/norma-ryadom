package ru.normaryadom.common

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.common.ratelimit.ClientKey

class ClientKeyTest {
    @Test
    fun `оставляет IPv4-адрес как есть`() {
        assertThat(ClientKey.of("203.0.113.7")).isEqualTo("203.0.113.7")
    }

    @Test
    fun `сводит IPv6-адреса одной сети 64 к одному ключу`() {
        val first = ClientKey.of("2001:db8:1:2:aaaa:bbbb:cccc:dddd")
        val second = ClientKey.of("2001:db8:1:2::1")

        assertThat(first).isEqualTo(second).isEqualTo("2001:db8:1:2:0:0:0:0/64")
        assertThat(ClientKey.of("2001:db8:1:3::1")).isNotEqualTo(first)
    }

    @Test
    fun `не обращается к DNS для имён`() {
        assertThat(ClientKey.of("dead.beef")).isEqualTo("dead.beef")
        assertThat(ClientKey.of("example.com")).isEqualTo("example.com")
    }
}
