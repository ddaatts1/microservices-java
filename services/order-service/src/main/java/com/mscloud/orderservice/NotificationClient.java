package com.mscloud.orderservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class NotificationClient {
    private static final Logger log = LoggerFactory.getLogger(NotificationClient.class);

    private final RestClient notificationClient;

    public NotificationClient(@Value("${NOTIFICATION_SERVICE_URL:http://localhost:8084}") String notificationServiceUrl) {
        this.notificationClient = RestClient.create(notificationServiceUrl);
    }

    public void notifyOrderCreated(Order order) {
        try {
            notificationClient.post()
                    .uri("/api/notifications/test")
                    .body(new TestNotificationRequest(
                            order.externalUserId(),
                            "Order created",
                            "Order " + order.id() + " was created with total " + order.totalAmount()
                    ))
                    .retrieve()
                    .toBodilessEntity();
        } catch (RuntimeException ex) {
            log.warn("Could not notify order creation orderId={} reason={}", order.id(), ex.getMessage());
        }
    }
}

