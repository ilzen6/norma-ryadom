package ru.normaryadom.support

import org.springframework.boot.ApplicationRunner
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.context.annotation.Bean
import org.springframework.test.context.DynamicPropertyRegistrar
import org.testcontainers.containers.GenericContainer
import org.testcontainers.containers.wait.strategy.Wait
import org.testcontainers.postgresql.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import ru.normaryadom.intake.config.StorageProperties
import software.amazon.awssdk.services.s3.S3Client
import java.time.Duration

@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {
    @Bean
    @ServiceConnection
    fun postgis(): PostgreSQLContainer = PostgreSQLContainer(DockerImageName.parse(POSTGIS_IMAGE).asCompatibleSubstituteFor("postgres"))

    @Bean
    fun seaweedFs(): GenericContainer<*> =
        GenericContainer(DockerImageName.parse(SEAWEEDFS_IMAGE))
            .withEnv("S3_ACCESS_KEY", ACCESS_KEY)
            .withEnv("S3_SECRET_KEY", SECRET_KEY)
            .withCreateContainerCmdModifier { it.withEntrypoint("sh", "-c", SEAWEEDFS_START) }
            .withExposedPorts(S3_PORT)
            .waitingFor(
                Wait
                    .forHttp("/")
                    .forPort(S3_PORT)
                    .forStatusCode(403)
                    .withStartupTimeout(Duration.ofMinutes(2)),
            )

    @Bean
    fun storageEndpoint(seaweedFs: GenericContainer<*>): DynamicPropertyRegistrar =
        DynamicPropertyRegistrar { registry ->
            registry.add("storage.endpoint") { "http://${seaweedFs.host}:${seaweedFs.getMappedPort(S3_PORT)}" }
        }

    @Bean
    fun testBucket(
        s3: S3Client,
        properties: StorageProperties,
    ): ApplicationRunner =
        ApplicationRunner {
            val exists = s3.listBuckets().buckets().any { it.name() == properties.bucket }
            if (!exists) s3.createBucket { it.bucket(properties.bucket) }
        }

    companion object {
        const val POSTGIS_IMAGE = "postgis/postgis:16-3.4"
        const val SEAWEEDFS_IMAGE = "chrislusf/seaweedfs:3.97"
        const val ACCESS_KEY = "test-access-key"
        const val SECRET_KEY = "test-secret-key"
        const val S3_PORT = 8333
        private const val SEAWEEDFS_START =
            "printf '{\"identities\":[{\"name\":\"app\",\"credentials\":[{\"accessKey\":\"%s\",\"secretKey\":\"%s\"}]," +
                "\"actions\":[\"Admin\",\"Read\",\"Write\",\"List\",\"Tagging\"]}]}'" +
                " \"\$S3_ACCESS_KEY\" \"\$S3_SECRET_KEY\" > /tmp/s3.json" +
                " && exec weed server -s3 -s3.config=/tmp/s3.json -dir=/data"
    }
}
