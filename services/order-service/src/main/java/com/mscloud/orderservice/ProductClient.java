package com.mscloud.orderservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Optional;
import java.util.UUID;

@Component
public class ProductClient {
    private final RestClient productClient;

    public ProductClient(@Value("${PRODUCT_SERVICE_URL:http://localhost:8082}") String productServiceUrl) {
        this.productClient = RestClient.create(productServiceUrl);
    }

    public Optional<ProductSummary> findById(UUID productId) {
        try {
            ProductSummary product = productClient.get()
                    .uri("/api/products/{id}", productId)
                    .retrieve()
                    .body(ProductSummary.class);
            return Optional.ofNullable(product);
        } catch (RuntimeException ex) {
            return Optional.empty();
        }
    }
}

