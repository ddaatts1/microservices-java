package com.mscloud.productservice;

import java.math.BigDecimal;
import java.util.UUID;

public record Product(
        UUID id,
        String name,
        BigDecimal price,
        String description,
        int stock
) {
}

