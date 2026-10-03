package ru.normaryadom.admin

import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestBuilders.formLogin
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user
import org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.authenticated
import org.springframework.security.test.web.servlet.response.SecurityMockMvcResultMatchers.unauthenticated
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.multipart
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.RequestPostProcessor
import ru.normaryadom.intake.photo.MenuPhotoService
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest
import ru.normaryadom.support.MenuPhotos

class AdminWebIT : IntegrationTest() {
    @Autowired
    private lateinit var photos: MenuPhotoService

    private val admin: RequestPostProcessor = user("test-admin").roles("ADMIN")

    @Test
    fun `пускает в админку только после входа`() {
        mockMvc.get("/admin").andExpect {
            status { is3xxRedirection() }
            redirectedUrl("/admin/login")
        }
        mockMvc.get("/admin/login").andExpect {
            status { isOk() }
            content { string(containsString("Вход в админку")) }
        }
        mockMvc.perform(formLogin("/admin/login").user("test-admin").password("wrong")).andExpect(unauthenticated())
        mockMvc.perform(formLogin("/admin/login").user("test-admin").password("test-password")).andExpect(authenticated())
    }

    @Test
    fun `блокирует вход после серии попыток с одного адреса`() {
        val client = uniqueClient()
        repeat(LOGIN_ATTEMPTS) {
            login(client, "wrong-$it").andExpect { redirectedUrl("/admin/login?error") }
        }

        login(client, "test-password").andExpect { redirectedUrl("/admin/login?locked") }
        mockMvc.get("/admin/login") { param("locked", "") }.andExpect {
            content { string(containsString("Слишком много попыток")) }
        }
        login(uniqueClient(), "test-password").andExpect { redirectedUrl("/admin") }
    }

    @Test
    fun `не принимает изменения без CSRF-токена и от пользователя без роли`() {
        mockMvc
            .post("/admin/chains") {
                with(admin)
                param("name", "Сеть")
            }.andExpect { status { isForbidden() } }
        mockMvc
            .get("/admin/chains") { with(user("someone").roles("USER")) }
            .andExpect { status { isForbidden() } }
        assertThat(jdbc.sql("SELECT count(*) FROM chain").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `закрывает внутренние эндпоинты actuator`() {
        mockMvc.get("/actuator/health").andExpect { status { isOk() } }
        mockMvc.get("/actuator/env").andExpect { status { is3xxRedirection() } }
        mockMvc.get("/actuator/env") { with(admin) }.andExpect { status { isForbidden() } }
        mockMvc.get("/actuator/beans") { with(admin) }.andExpect { status { isForbidden() } }
    }

    @Test
    fun `создаёт сеть и загружает её меню и точки из CSV`() {
        mockMvc
            .post("/admin/chains") {
                with(admin)
                with(csrf())
                param("name", "Новая сеть")
                param("sourceUrl", "https://new.example/kbju")
            }.andExpect {
                status { is3xxRedirection() }
                redirectedUrlPattern("/admin/chains/*")
            }
        val chainId = jdbc.sql("SELECT id FROM chain WHERE name = 'Новая сеть'").query(Long::class.java).single()

        mockMvc
            .multipart("/admin/chains/$chainId/menu") {
                file(MockMultipartFile("file", "menu.csv", "text/csv", catalog.menuCsv(GRILL_MENU)))
                param("sourceUrl", "https://new.example/kbju")
                with(admin)
                with(csrf())
            }.andExpect {
                status { is3xxRedirection() }
                flash { attributeExists("imported") }
            }
        mockMvc
            .multipart("/admin/chains/$chainId/venues") {
                file(MockMultipartFile("file", "venues.csv", "text/csv", catalog.venueCsv(GRILL_VENUES)))
                with(admin)
                with(csrf())
            }.andExpect { flash { attributeExists("imported") } }

        mockMvc.get("/admin/chains/$chainId") { with(admin) }.andExpect {
            status { isOk() }
            content { string(containsString("Куриная грудка гриль")) }
            content { string(containsString("Гриль, Тверская")) }
        }
        mockMvc.get("/admin") { with(admin) }.andExpect {
            content { string(containsString("data-testid=\"chain-count\">1<")) }
        }
    }

    @Test
    fun `показывает ошибки CSV построчно и не меняет меню`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .multipart("/admin/chains/$chainId/menu") {
                val invalid = catalog.menuCsv(listOf("Суп;soup;300;200;5;5;20;150;"))
                file(MockMultipartFile("file", "menu.csv", "text/csv", invalid))
                param("sourceUrl", "https://chain.example/nutrition")
                with(admin)
                with(csrf())
            }.andExpect { flash { attributeExists("csvErrors") } }
        mockMvc
            .multipart("/admin/chains/$chainId/menu") {
                file(MockMultipartFile("file", "menu.csv", "text/csv", catalog.menuCsv(GRILL_MENU)))
                param("sourceUrl", "javascript:alert(1)")
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("importError", "import.sourceUrl.invalid") } }

        assertThat(jdbc.sql("SELECT count(*) FROM menu_item WHERE name = 'Суп'").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `не создаёт сеть с повторяющимся названием и подсвечивает поле`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .post("/admin/chains") {
                with(admin)
                with(csrf())
                param("name", "Гриль")
                param("sourceUrl", "")
            }.andExpect {
                status { isOk() }
                content { string(containsString("Сеть с таким названием уже есть")) }
            }
        mockMvc
            .post("/admin/chains") {
                with(admin)
                with(csrf())
                param("name", "")
                param("sourceUrl", "ftp://bad")
            }.andExpect {
                status { isOk() }
                content { string(containsString("field-error")) }
            }
    }

    @Test
    fun `модератор принимает фото меню, и блюда уровня B появляются в меню заведения`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = jdbc.sql("SELECT id FROM venue WHERE external_id = 'grill-02'").query(Long::class.java).single()
        val submissionId = photos.submit(venueId, MenuPhotos.withText(listOf("Шаурма 520")), "10.9.9.1").submissionId

        mockMvc.get("/admin/moderation") { with(admin) }.andExpect {
            content { string(containsString("Гриль, Тверская")) }
        }
        mockMvc.get("/admin/moderation/$submissionId") { with(admin) }.andExpect {
            status { isOk() }
            content { string(containsString("name;category;portion_g")) }
        }
        mockMvc.get("/admin/moderation/$submissionId/photo") { with(admin) }.andExpect {
            status { isOk() }
            content { contentType("image/png") }
            header { string("X-Content-Type-Options", "nosniff") }
        }
        mockMvc
            .post("/admin/moderation/$submissionId/approve") {
                with(admin)
                with(csrf())
                param("menuCsv", String(catalog.menuCsv(listOf("Шаурма куриная;main;300;520;32;22;48;320;chicken,gluten"))))
            }.andExpect { flash { attribute("approvedItems", 1) } }

        mockMvc.get("/api/v1/venues/$venueId/menu").andExpect {
            jsonPath("$.items[?(@.name == 'Шаурма куриная')].source.kind") { value("B") }
            jsonPath("$.items[?(@.name == 'Куриная грудка гриль')].source.kind") { value("A") }
        }
        assertThat(jdbc.sql("SELECT status FROM menu_submission").query(String::class.java).single()).isEqualTo("APPROVED")
        mockMvc
            .post("/admin/moderation/$submissionId/reject") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("alreadyModerated", true) } }
    }

    @Test
    fun `модератор видит ошибки строк меню и может отклонить фото`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = jdbc.sql("SELECT id FROM venue WHERE external_id = 'grill-01'").query(Long::class.java).single()
        val submissionId = photos.submit(venueId, MenuPhotos.withText(listOf("x")), "10.9.9.2").submissionId

        mockMvc
            .post("/admin/moderation/$submissionId/approve") {
                with(admin)
                with(csrf())
                param("menuCsv", String(catalog.menuCsv(listOf("Блюдо;main;;много;1;1;1;;"))))
            }.andExpect {
                flash { attributeExists("csvErrors") }
                redirectedUrl("/admin/moderation/$submissionId")
            }
        mockMvc
            .post("/admin/moderation/$submissionId/reject") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("rejected", true) } }

        assertThat(jdbc.sql("SELECT status FROM menu_submission").query(String::class.java).single()).isEqualTo("REJECTED")
        mockMvc.get("/admin/moderation") { with(admin) }.andExpect {
            content { string(not(containsString("/admin/moderation/$submissionId\""))) }
        }
        mockMvc.get("/admin/moderation/${Long.MAX_VALUE}") { with(admin) }.andExpect { status { isNotFound() } }
    }

    @Test
    fun `модератор разбирает жалобы - подтверждает, исправляет и снимает блюда`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val confirmed = underReview("Морс")
        val corrected = underReview("Рис с овощами")
        val withdrawn = underReview("Чай")

        mockMvc.get("/admin/reviews") { with(admin) }.andExpect {
            content { string(containsString("Слишком много калорий")) }
        }
        mockMvc
            .post("/admin/reviews/$confirmed/confirm") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("resolved", "confirmed") } }
        mockMvc
            .post("/admin/reviews/$corrected/correct") {
                with(admin)
                with(csrf())
                param("kcal", "250")
                param("protein", "5")
                param("fat", "6")
                param("carbs", "42")
            }.andExpect { flash { attribute("resolved", "corrected") } }
        mockMvc
            .post("/admin/reviews/$withdrawn/correct") {
                with(admin)
                with(csrf())
                param("kcal", "")
            }.andExpect { flash { attribute("correctionError", withdrawn) } }
        mockMvc
            .post("/admin/reviews/$withdrawn/withdraw") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("resolved", "withdrawn") } }

        val rows =
            jdbc
                .sql("SELECT name, kcal, is_available, under_review FROM menu_item")
                .query()
                .listOfRows()
                .associateBy { it["name"] }
        assertThat(rows.getValue("Морс")["under_review"]).isEqualTo(false)
        assertThat(rows.getValue("Рис с овощами")["kcal"].toString()).isEqualTo("250.0")
        assertThat(rows.getValue("Чай")["is_available"]).isEqualTo(false)
        assertThat(jdbc.sql("SELECT count(*) FROM item_report WHERE resolved_at IS NULL").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `модератор разбирает сообщения о закрытых точках - возвращает работающую и убирает закрытую`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val working = suspectedClosed("Гриль, Сити")
        val closed = suspectedClosed("Гриль, Тверская")

        mockMvc.get("/admin") { with(admin) }.andExpect {
            content { string(containsString("data-testid=\"venue-cases\">2<")) }
        }
        mockMvc.get("/admin/venue-reviews") { with(admin) }.andExpect {
            content { string(containsString("Гриль, Тверская")) }
            content { string(containsString("Закрыто: 1")) }
        }
        mockMvc
            .post("/admin/venue-reviews/$working/restore") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("resolved", "restored") } }
        mockMvc
            .post("/admin/venue-reviews/$closed/close") {
                with(admin)
                with(csrf())
            }.andExpect { flash { attribute("resolved", "closed") } }

        val rows =
            jdbc
                .sql("SELECT name, is_active, under_review, confirmed_on FROM venue")
                .query()
                .listOfRows()
                .associateBy { it["name"] }
        assertThat(rows.getValue("Гриль, Сити")["is_active"]).isEqualTo(true)
        assertThat(rows.getValue("Гриль, Сити")["confirmed_on"]).isNotNull()
        assertThat(rows.getValue("Гриль, Тверская")["is_active"]).isEqualTo(false)
        assertThat(jdbc.sql("SELECT count(*) FROM venue_report WHERE resolved_at IS NULL").query(Int::class.java).single()).isZero()
    }

    private fun suspectedClosed(name: String): Long {
        val id =
            jdbc
                .sql("SELECT id FROM venue WHERE name = :name")
                .param("name", name)
                .query(Long::class.java)
                .single()
        jdbc.sql("UPDATE venue SET under_review = TRUE WHERE id = :id").param("id", id).update()
        jdbc
            .sql("INSERT INTO venue_report (venue_id, reason, reporter_hash) VALUES (:id, 'closed', 'test')")
            .param("id", id)
            .update()
        return id
    }

    private fun underReview(name: String): Long {
        val id =
            jdbc
                .sql("SELECT id FROM menu_item WHERE name = :name")
                .param("name", name)
                .query(Long::class.java)
                .single()
        jdbc.sql("UPDATE menu_item SET under_review = TRUE WHERE id = :id").param("id", id).update()
        jdbc.sql("INSERT INTO item_report (item_id, reason) VALUES (:id, 'Слишком много калорий')").param("id", id).update()
        return id
    }

    private fun login(
        client: RequestPostProcessor,
        password: String,
    ) = mockMvc.post("/admin/login") {
        param("username", "test-admin")
        param("password", password)
        with(csrf())
        with(client)
    }

    private companion object {
        const val LOGIN_ATTEMPTS = 10
    }
}
