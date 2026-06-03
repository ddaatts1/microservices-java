package com.mscloud.orderservice;

import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class OrderService {
    private final ProductClient productClient;
    private final OrderRepository orders;
    private final OrderEventPublisher events;
    private final NotificationClient notifications;

    public OrderService(ProductClient productClient, OrderRepository orders, OrderEventPublisher events, NotificationClient notifications) {
        this.productClient = productClient;
        this.orders = orders;
        this.events = events;
        this.notifications = notifications;
    }

    public Optional<Order> create(String externalUserId, CreateOrderRequest request) {
        Optional<ProductSummary> productResult = productClient.findById(request.productId());
        if (productResult.isEmpty()) {
            return Optional.empty();
        }
        ProductSummary product = productResult.get();
        BigDecimal totalAmount = product.price().multiply(BigDecimal.valueOf(request.quantity()));
        Order order = new Order(
                UUID.randomUUID(),
                externalUserId,
                product.id(),
                product.name(),
                request.quantity(),
                product.price(),
                totalAmount,
                OrderStatus.CREATED,
                Instant.now()
        );
        orders.save(order);
        events.publishOrderCreated(order);
        notifications.notifyOrderCreated(order);
        return Optional.of(order);
    }

    public List<Order> findMyOrders(String externalUserId) {
        return orders.findByExternalUserId(externalUserId);
    }

    public Optional<Order> findById(UUID orderId) {
        return orders.findById(orderId);
    }

    public List<Order> findAll() {
        return orders.findAll();
    }
}
