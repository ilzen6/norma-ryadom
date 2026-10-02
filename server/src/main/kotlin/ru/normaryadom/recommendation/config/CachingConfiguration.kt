package ru.normaryadom.recommendation.config

import org.springframework.cache.annotation.EnableCaching
import org.springframework.context.annotation.Configuration

@Configuration(proxyBeanMethods = false)
@EnableCaching
class CachingConfiguration
