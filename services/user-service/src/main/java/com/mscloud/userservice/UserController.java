package com.mscloud.userservice;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final UserRepository users;

    public UserController(UserRepository users) {
        this.users = users;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("service", "user-service", "status", "UP");
    }

    @GetMapping("/me")
    public UserProfile me(
            @RequestHeader(value = "X-User-Id", defaultValue = "dev-user-001") String externalUserId,
            @RequestHeader(value = "X-User-Email", defaultValue = "dev@example.com") String email
    ) {
        return users.findOrCreate(externalUserId, email);
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserProfile> findById(@PathVariable UUID id) {
        return users.findById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping
    public List<UserProfile> findAll() {
        return users.findAll();
    }
}

