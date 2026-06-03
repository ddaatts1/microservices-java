package com.mscloud.orderservice;

import java.math.BigDecimal;
import java.util.UUID;

public record ProductSummary(
        UUID id,
        String name,
        BigDecimal price,
        String description,
        int stock
) {
}

