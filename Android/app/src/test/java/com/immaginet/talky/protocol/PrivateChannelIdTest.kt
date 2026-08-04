package com.immaginet.talky.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PrivateChannelIdTest {
    @Test
    fun `password derives the same lowercase SHA256 prefix used by Apple`() {
        assertEquals("a1e38253fad330df", PrivateChannelId.fromPassword("talky123"))
        assertEquals("03ac674216f3e15c", PrivateChannelId.fromPassword("1234"))
    }

    @Test
    fun `password shorter than four characters is rejected`() {
        assertThrows(IllegalArgumentException::class.java) {
            PrivateChannelId.fromPassword("123")
        }
    }
}
