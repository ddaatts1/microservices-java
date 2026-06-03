package com.mscloud.orderservice;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
public class OrderController {
    private final OrderService orders;

    public OrderController(OrderService orders) {
        this.orders = orders;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("service", "order-service", "status", "UP");
    }

    @PostMapping
    public ResponseEntity<Order> create(
            @RequestHeader(value = "X-User-Id", defaultValue = "dev-user-001") String externalUserId,
            @Valid @RequestBody CreateOrderRequest request
    ) {
        return orders.create(externalUserId, request)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping("/my")
    public List<Order> myOrders(@RequestHeader(value = "X-User-Id", defaultValue = "dev-user-001") String externalUserId) {
        return orders.findMyOrders(externalUserId);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Order> findById(@PathVariable UUID id) {
        return orders.findById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping
    public List<Order> findAll() {
        return orders.findAll();
    }
}

