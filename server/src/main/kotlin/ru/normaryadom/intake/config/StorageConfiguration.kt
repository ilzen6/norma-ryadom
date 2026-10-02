package ru.normaryadom.intake.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.core.checksums.RequestChecksumCalculation
import software.amazon.awssdk.core.checksums.ResponseChecksumValidation
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.S3Configuration

@Configuration(proxyBeanMethods = false)
class StorageConfiguration {
    @Bean(destroyMethod = "close")
    fun s3Client(properties: StorageProperties): S3Client =
        S3Client
            .builder()
            .endpointOverride(properties.endpoint)
            .region(Region.of(properties.region))
            .credentialsProvider(
                StaticCredentialsProvider.create(AwsBasicCredentials.create(properties.accessKey, properties.secretKey)),
            ).serviceConfiguration(
                S3Configuration
                    .builder()
                    .pathStyleAccessEnabled(true)
                    .chunkedEncodingEnabled(false)
                    .build(),
            ).requestChecksumCalculation(RequestChecksumCalculation.WHEN_REQUIRED)
            .responseChecksumValidation(ResponseChecksumValidation.WHEN_REQUIRED)
            .httpClientBuilder(
                UrlConnectionHttpClient
                    .builder()
                    .connectionTimeout(properties.connectTimeout)
                    .socketTimeout(properties.callTimeout),
            ).overrideConfiguration(
                ClientOverrideConfiguration
                    .builder()
                    .apiCallTimeout(properties.callTimeout)
                    .apiCallAttemptTimeout(properties.callTimeout)
                    .build(),
            ).build()
}
