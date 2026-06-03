package com.mscloud.orderservice;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
public class OrderRepository {
    private final JdbcTemplate jdbc;
    private final RowMapper<Order> orderMapper = (rs, rowNum) -> new Order(
            rs.getObject("id", UUID.class),
            rs.getString("external_user_id"),
            rs.getObject("product_id", UUID.class),
            rs.getString("product_name"),
            rs.getInt("quantity"),
            rs.getBigDecimal("unit_price"),
            rs.getBigDecimal("total_amount"),
            OrderStatus.valueOf(rs.getString("status")),
            rs.getTimestamp("created_at").toInstant()
    );

    public OrderRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Order save(Order order) {
        jdbc.update(
                """
                INSERT INTO orders (id, external_user_id, product_id, product_name, quantity, unit_price, total_amount, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                order.id(),
                order.externalUserId(),
                order.productId(),
                order.productName(),
                order.quantity(),
                order.unitPrice(),
                order.totalAmount(),
                order.status().name(),
                Timestamp.from(order.createdAt())
        );
        return order;
    }

    public Optional<Order> findById(UUID id) {
        return jdbc.query("SELECT * FROM orders WHERE id = ?", orderMapper, id).stream().findFirst();
    }

    public List<Order> findByExternalUserId(String externalUserId) {
        return jdbc.query(
                "SELECT * FROM orders WHERE external_user_id = ? ORDER BY created_at DESC",
                orderMapper,
                externalUserId
        );
    }

    public List<Order> findAll() {
        return jdbc.query("SELECT * FROM orders ORDER BY created_at DESC", orderMapper);
    }
}
