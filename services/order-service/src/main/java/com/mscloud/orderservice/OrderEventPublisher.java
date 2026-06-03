package com.mscloud.orderservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class OrderEventPublisher {
    private static final Logger log = LoggerFactory.getLogger(OrderEventPublisher.class);

    public void publishOrderCreated(Order order) {
        log.info("event=OrderCreated orderId={} userId={} totalAmount={}", order.id(), order.externalUserId(), order.totalAmount());
    }
}

