package ru.normaryadom.site

import org.hamcrest.Matchers.containsString
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.get
import ru.normaryadom.support.IntegrationTest

class PrivacyPageIT : IntegrationTest() {
    @Test
    fun `открывает политику конфиденциальности без входа`() {
        mockMvc.get("/privacy").andExpect {
            status { isOk() }
            content { contentTypeCompatibleWith("text/html") }
            content { string(containsString("Политика конфиденциальности приложения «Норма рядом»")) }
            content { string(containsString("Что хранится только на телефоне")) }
            header { string("Cache-Control", containsString("max-age=3600")) }
        }
    }

    @Test
    fun `отмечает места для даты и почты, пока их не задали в настройках`() {
        mockMvc.get("/privacy").andExpect {
            content { string(containsString("data-testid=\"published-on\">[ДАТА ПУБЛИКАЦИИ]<")) }
            content { string(containsString("data-testid=\"contact-email\">[ПОЧТА ДЛЯ СВЯЗИ]<")) }
        }
    }

    @Test
    fun `не открывает без входа другие адреса рядом с политикой`() {
        mockMvc.get("/privacy/admin").andExpect {
            status { is3xxRedirection() }
            redirectedUrl("/admin/login")
        }
    }
}
