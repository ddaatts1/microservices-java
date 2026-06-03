package com.mscloud.productservice;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
public class ProductRepository {
    private final JdbcTemplate jdbc;
    private final RowMapper<Product> productMapper = (rs, rowNum) -> new Product(
            rs.getObject("id", UUID.class),
            rs.getString("name"),
            rs.getBigDecimal("price"),
            rs.getString("description"),
            rs.getInt("stock")
    );

    public ProductRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Product> findAll() {
        return jdbc.query("SELECT * FROM products ORDER BY name", productMapper);
    }

    public Optional<Product> findById(UUID id) {
        return jdbc.query("SELECT * FROM products WHERE id = ?", productMapper, id).stream().findFirst();
    }

    public Product create(ProductRequest request) {
        Product product = new Product(UUID.randomUUID(), request.name(), request.price(), request.description(), request.stock());
        jdbc.update(
                """
                INSERT INTO products (id, name, price, description, stock, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, NOW(), NOW())
                """,
                product.id(),
                product.name(),
                product.price(),
                product.description(),
                product.stock()
        );
        return product;
    }

    public Optional<Product> update(UUID id, ProductRequest request) {
        int updated = jdbc.update(
                """
                UPDATE products
                SET name = ?, price = ?, description = ?, stock = ?, updated_at = NOW()
                WHERE id = ?
                """,
                request.name(),
                request.price(),
                request.description(),
                request.stock(),
                id
        );
        if (updated == 0) {
            return Optional.empty();
        }
        return findById(id);
    }
}
