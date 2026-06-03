package com.mscloud.orderservice;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record Order(
        UUID id,
        String externalUserId,
        UUID productId,
        String productName,
        int quantity,
        BigDecimal unitPrice,
        BigDecimal totalAmount,
        OrderStatus status,
        Instant createdAt
) {
}

