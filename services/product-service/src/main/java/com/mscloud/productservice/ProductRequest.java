package com.mscloud.productservice;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;

public record ProductRequest(
        @NotBlank String name,
        @DecimalMin("0.0") BigDecimal price,
        String description,
        @Min(0) int stock
) {
}

