package com.mscloud.gatewayservice;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

import java.util.Collection;

@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class SecurityConfig {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, AuthProperties authProperties) throws Exception {
        http.csrf(csrf -> csrf.disable());

        if (!authProperties.enabled()) {
            return http
                    .authorizeHttpRequests(requests -> requests.anyRequest().permitAll())
                    .build();
        }

        http.authorizeHttpRequests(requests -> requests
                .requestMatchers("/api/health", "/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/api/products", "/api/products/**").permitAll()
                .anyRequest().authenticated()
        );
        http.oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }

    @Bean
    JwtDecoder jwtDecoder(AuthProperties authProperties) {
        if (!authProperties.enabled()) {
            return token -> Jwt.withTokenValue(token)
                    .header("alg", "none")
                    .subject("dev-user-001")
                    .claim("email", "dev@example.com")
                    .build();
        }

        if (isBlank(authProperties.issuerUri())) {
            throw new IllegalStateException("AUTH_ISSUER_URI is required when AUTH_ENABLED=true.");
        }

        NimbusJwtDecoder decoder = JwtDecoders.fromIssuerLocation(authProperties.issuerUri());
        OAuth2TokenValidator<Jwt> issuer = JwtValidators.createDefaultWithIssuer(authProperties.issuerUri());
        if (isBlank(authProperties.audience())) {
            decoder.setJwtValidator(issuer);
        } else {
            decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(issuer, audienceValidator(authProperties.audience())));
        }
        return decoder;
    }

    private OAuth2TokenValidator<Jwt> audienceValidator(String expectedAudience) {
        return jwt -> {
            Collection<String> audiences = jwt.getAudience();
            if (audiences != null && audiences.contains(expectedAudience)) {
                return OAuth2TokenValidatorResult.success();
            }
            OAuth2Error error = new OAuth2Error("invalid_token", "Missing required audience.", null);
            return OAuth2TokenValidatorResult.failure(error);
        };
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
