package com.mscloud.productservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class ProductSyncListener {
    private static final Logger log = LoggerFactory.getLogger(ProductSyncListener.class);
    private final ProductSearchRepository searchRepository;

    private final ProductRepository productRepository;

    public ProductSyncListener(ProductSearchRepository searchRepository, ProductRepository productRepository) {
        this.searchRepository = searchRepository;
        this.productRepository = productRepository;
    }

    @RabbitListener(queues = RabbitMQConfig.PRODUCT_SYNC_QUEUE)
    public void syncProductToElasticsearch(UUID productId) {
        log.info("Received Outbox event from RabbitMQ: Syncing Product {} to Elasticsearch...", productId);
        try {
            productRepository.findById(productId).ifPresent(product -> {
                searchRepository.save(ProductDocument.fromProduct(product));
                log.info("Successfully synced Product {} to Elasticsearch.", productId);
            });
        } catch (Exception e) {
            log.error("Error syncing Product {} to Elasticsearch! Message will be requeued.", productId, e);
            throw e;
        }
    }
}
