package com.mscloud.productservice;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    private final ProductRepository products;
    private final ProductSearchRepository searchRepository;

    public ProductController(ProductRepository products, ProductSearchRepository searchRepository) {
        this.products = products;
        this.searchRepository = searchRepository;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("service", "product-service", "status", "UP");
    }

    @GetMapping("/search")
    public List<ProductDocument> search(@org.springframework.web.bind.annotation.RequestParam("q") String query) {
        return searchRepository.findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCase(query, query);
    }

    @GetMapping
    public List<Product> findAll() {
        return products.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> findById(@PathVariable UUID id) {
        return products.findById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping
    public Product create(@Valid @RequestBody ProductRequest request) {
        return products.create(request);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> update(@PathVariable UUID id, @Valid @RequestBody ProductRequest request) {
        return products.update(id, request)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}

