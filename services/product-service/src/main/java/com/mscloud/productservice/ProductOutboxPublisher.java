package com.mscloud.productservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Component
public class ProductOutboxPublisher {
    private static final Logger log = LoggerFactory.getLogger(ProductOutboxPublisher.class);
    private final JdbcTemplate jdbc;
    private final RabbitTemplate rabbitTemplate;

    public ProductOutboxPublisher(JdbcTemplate jdbc, RabbitTemplate rabbitTemplate) {
        this.jdbc = jdbc;
        this.rabbitTemplate = rabbitTemplate;
    }

    @Scheduled(fixedDelay = 2000)
    @Transactional
    public void publishOutboxEvents() {
        List<Map<String, Object>> pendingEvents = jdbc.queryForList(
                "SELECT id, product_id FROM product_outbox WHERE status = 'PENDING' ORDER BY created_at ASC LIMIT 50"
        );

        if (pendingEvents.isEmpty()) {
            return;
        }

        log.info("Found {} pending outbox events. Publishing to RabbitMQ...", pendingEvents.size());

        for (Map<String, Object> event : pendingEvents) {
            UUID outboxId = (UUID) event.get("id");
            UUID productId = (UUID) event.get("product_id");

            try {
                // Send just the productId as the payload. The consumer will fetch fresh data from DB.
                rabbitTemplate.convertAndSend(RabbitMQConfig.PRODUCT_EXCHANGE, RabbitMQConfig.PRODUCT_SYNC_ROUTING_KEY, productId);

                // Mark as published
                jdbc.update("UPDATE product_outbox SET status = 'PUBLISHED' WHERE id = ?", outboxId);
            } catch (Exception e) {
                log.error("Failed to publish outbox event id: {}", outboxId, e);
                // Break loop or continue; typically we might stop to preserve order, but let's just log and continue or throw to rollback
                throw e; // Rollback the transaction so they remain PENDING
            }
        }
        
        log.info("Successfully published {} events.", pendingEvents.size());
    }
}
