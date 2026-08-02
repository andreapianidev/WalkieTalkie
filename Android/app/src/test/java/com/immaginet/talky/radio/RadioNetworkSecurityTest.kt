package com.immaginet.talky.radio

import java.io.File
import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RadioNetworkSecurityTest {
    private val sourceRoot: File = sequenceOf(
        File("app/src/main"),
        File("src/main")
    ).first { it.isDirectory }

    @Test
    fun everyHttpRadioHostIsExplicitlyAllowlisted() {
        val config = File(sourceRoot, "res/xml/network_security_config.xml")
        assertTrue("network_security_config.xml is missing", config.isFile)

        val radioSource = File(
            sourceRoot,
            "java/com/immaginet/talky/radio/RadioManager.kt"
        ).readText()
        val httpHosts = HTTP_URL_REGEX.findAll(radioSource)
            .mapNotNull { match -> URI(match.value).host }
            .toSortedSet()
        val allowedDomains = DOMAIN_REGEX.findAll(config.readText())
            .map { match -> match.groupValues[1] }
            .toSortedSet()

        assertEquals(httpHosts, allowedDomains)
    }

    @Test
    fun cleartextIsDeniedByDefault() {
        val configText = File(
            sourceRoot,
            "res/xml/network_security_config.xml"
        ).readText()

        assertTrue(configText.contains("<base-config cleartextTrafficPermitted=\"false\""))
        assertFalse(configText.contains("<base-config cleartextTrafficPermitted=\"true\""))
    }

    @Test
    fun manifestUsesDomainScopedNetworkPolicy() {
        val manifestText = File(sourceRoot, "AndroidManifest.xml").readText()

        assertTrue(manifestText.contains("android:networkSecurityConfig=\"@xml/network_security_config\""))
        assertFalse(manifestText.contains("android:usesCleartextTraffic=\"true\""))
    }

    private companion object {
        val HTTP_URL_REGEX = Regex("http://[^\\\"]+")
        val DOMAIN_REGEX = Regex("<domain(?:\\s+includeSubdomains=\"(?:true|false)\")?>([^<]+)</domain>")
    }
}
