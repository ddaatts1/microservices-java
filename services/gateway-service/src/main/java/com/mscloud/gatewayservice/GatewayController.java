package com.mscloud.gatewayservice;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class GatewayController {
    private final RestClient userClient;
    private final RestClient productClient;
    private final RestClient orderClient;
    private final RestClient notificationClient;

    public GatewayController(
            @Value("${USER_SERVICE_URL:http://localhost:8081}") String userServiceUrl,
            @Value("${PRODUCT_SERVICE_URL:http://localhost:8082}") String productServiceUrl,
            @Value("${ORDER_SERVICE_URL:http://localhost:8083}") String orderServiceUrl,
            @Value("${NOTIFICATION_SERVICE_URL:http://localhost:8084}") String notificationServiceUrl
    ) {
        this.userClient = RestClient.create(userServiceUrl);
        this.productClient = RestClient.create(productServiceUrl);
        this.orderClient = RestClient.create(orderServiceUrl);
        this.notificationClient = RestClient.create(notificationServiceUrl);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("service", "gateway-service", "status", "UP");
    }

    @GetMapping("/me")
    public ResponseEntity<String> me(HttpServletRequest request, Authentication authentication) {
        return json(userClient.get()
                .uri("/api/users/me")
                .headers(headers -> copyIdentityHeaders(request, authentication, headers))
                .retrieve()
                .body(String.class));
    }

    @GetMapping("/products")
    public ResponseEntity<String> products() {
        return json(productClient.get()
                .uri("/api/products")
                .retrieve()
                .body(String.class));
    }

    @GetMapping("/products/{id}")
    public ResponseEntity<String> product(@PathVariable String id) {
        return json(productClient.get()
                .uri("/api/products/{id}", id)
                .retrieve()
                .body(String.class));
    }

    @PostMapping("/orders")
    public ResponseEntity<String> createOrder(@RequestBody String body, HttpServletRequest request, Authentication authentication) {
        return json(orderClient.post()
                .uri("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .headers(headers -> copyIdentityHeaders(request, authentication, headers))
                .body(body)
                .retrieve()
                .body(String.class));
    }

    @GetMapping("/orders/my")
    public ResponseEntity<String> myOrders(HttpServletRequest request, Authentication authentication) {
        return json(orderClient.get()
                .uri("/api/orders/my")
                .headers(headers -> copyIdentityHeaders(request, authentication, headers))
                .retrieve()
                .body(String.class));
    }

    @PostMapping("/notifications/test")
    public ResponseEntity<String> testNotification(@RequestBody String body) {
        return json(notificationClient.post()
                .uri("/api/notifications/test")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(String.class));
    }

    private ResponseEntity<String> json(String body) {
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .body(body);
    }

    private void copyIdentityHeaders(HttpServletRequest request, Authentication authentication, HttpHeaders headers) {
        GatewayIdentity identity = resolveIdentity(request, authentication);
        headers.set("X-User-Id", identity.userId());
        headers.set("X-User-Email", identity.email());
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization != null && !authorization.isBlank()) {
            headers.set(HttpHeaders.AUTHORIZATION, authorization);
        }
    }

    private GatewayIdentity resolveIdentity(HttpServletRequest request, Authentication authentication) {
        if (authentication != null && authentication.getPrincipal() instanceof Jwt jwt) {
            String userId = firstPresent(jwt.getSubject(), "unknown-user");
            String email = firstPresent(claim(jwt, "email"), firstPresent(claim(jwt, "preferred_username"), userId));
            return new GatewayIdentity(userId, email);
        }

        return new GatewayIdentity(
                firstPresent(request.getHeader("X-User-Id"), "dev-user-001"),
                firstPresent(request.getHeader("X-User-Email"), "dev@example.com")
        );
    }

    private String claim(Jwt jwt, String name) {
        Object value = jwt.getClaims().get(name);
        return value == null ? null : value.toString();
    }

    private String firstPresent(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }
}
