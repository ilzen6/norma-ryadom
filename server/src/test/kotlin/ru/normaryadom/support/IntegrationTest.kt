package ru.normaryadom.support

import org.junit.jupiter.api.BeforeEach
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.cache.CacheManager
import org.springframework.context.annotation.Import
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.RequestPostProcessor
import java.util.concurrent.atomic.AtomicInteger

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestcontainersConfiguration::class, CatalogFixtures::class)
abstract class IntegrationTest {
    @Autowired
    protected lateinit var mockMvc: MockMvc

    @Autowired
    protected lateinit var jdbc: JdbcClient

    @Autowired
    protected lateinit var catalog: CatalogFixtures

    @Autowired
    private lateinit var cacheManager: CacheManager

    @BeforeEach
    fun cleanState() {
        jdbc.sql("TRUNCATE item_report, menu_submission, menu_item, venue, chain CASCADE").update()
        cacheManager.cacheNames.forEach { name -> cacheManager.getCache(name)?.clear() }
    }

    protected fun uniqueClient(): RequestPostProcessor {
        val address = "10.1.${clients.incrementAndGet() / 250}.${clients.get() % 250 + 1}"
        return RequestPostProcessor { request: MockHttpServletRequest -> request.apply { remoteAddr = address } }
    }

    private companion object {
        val clients = AtomicInteger()
    }
}
