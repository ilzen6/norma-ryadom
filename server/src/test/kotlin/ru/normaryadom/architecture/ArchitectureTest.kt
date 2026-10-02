package ru.normaryadom.architecture

import com.tngtech.archunit.core.domain.JavaClasses
import com.tngtech.archunit.core.importer.ClassFileImporter
import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses
import com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices
import org.junit.jupiter.api.Test
import org.springframework.stereotype.Controller
import org.springframework.stereotype.Repository
import org.springframework.web.bind.annotation.RestController

class ArchitectureTest {
    private val classes: JavaClasses =
        ClassFileImporter()
            .withImportOption(ImportOption.DoNotIncludeTests())
            .importPackages("ru.normaryadom")

    @Test
    fun `алгоритм подбора не зависит от фреймворка, базы и веба`() {
        noClasses()
            .that()
            .resideInAPackage("..optimizer..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage("org.springframework..", "java.sql..", "jakarta..", "ru.normaryadom.catalog.persistence..")
            .check(classes)
    }

    @Test
    fun `модули верхнего уровня не образуют циклов`() {
        slices()
            .matching("ru.normaryadom.(*)..")
            .should()
            .beFreeOfCycles()
            .check(classes)
    }

    @Test
    fun `REST-контроллеры живут в пакетах api, а страницы админки - в admin`() {
        classes()
            .that()
            .areAnnotatedWith(RestController::class.java)
            .should()
            .resideInAPackage("..api..")
            .check(classes)
        classes()
            .that()
            .areAnnotatedWith(Controller::class.java)
            .should()
            .resideInAPackage("..admin..")
            .check(classes)
    }

    @Test
    fun `контроллеры не обращаются к репозиториям напрямую`() {
        noClasses()
            .that()
            .areAnnotatedWith(RestController::class.java)
            .or()
            .areAnnotatedWith(Controller::class.java)
            .should()
            .dependOnClassesThat()
            .areAnnotatedWith(Repository::class.java)
            .check(classes)
    }

    @Test
    fun `доменные модели каталога не зависят от слоёв приложения`() {
        noClasses()
            .that()
            .resideInAPackage("..catalog.domain..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage("org.springframework..", "java.sql..", "..persistence..", "..api..", "..web..")
            .check(classes)
    }

    @Test
    fun `интеграции хранилища и распознавания не знают о веб-слое`() {
        noClasses()
            .that()
            .resideInAnyPackage("..intake.storage..", "..intake.ocr..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage("..api..", "..web..", "..admin..")
            .check(classes)
    }
}
