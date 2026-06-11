package com.mscloud.productservice;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ProductControllerTest {
    private final ProductRepository products = mock(ProductRepository.class);
    private final ProductController controller = new ProductController(products, mock(ProductSearchRepository.class));

    @Test
    void healthReturnsServiceStatus() {
        Map<String, String> health = controller.health();

        assertThat(health)
                .containsEntry("service", "product-service")
                .containsEntry("status", "UP");
    }

    @Test
    void findAllReturnsProductsFromRepository() {
        Product sample = new Product(
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "Demo product",
                BigDecimal.valueOf(19.99),
                "Ready for Azure demo",
                10
        );
        when(products.findAll()).thenReturn(List.of(sample));

        assertThat(controller.findAll()).containsExactly(sample);
    }
}
