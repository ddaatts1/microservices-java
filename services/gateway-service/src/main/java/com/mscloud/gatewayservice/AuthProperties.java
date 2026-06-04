package com.mscloud.gatewayservice;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.auth")
public record AuthProperties(
        boolean enabled,
        String issuerUri,
        String audience
) {
}
