package com.mscloud.userservice;

import java.time.Instant;
import java.util.UUID;

public record UserProfile(
        UUID id,
        String externalUserId,
        String email,
        String displayName,
        String role,
        String status,
        Instant createdAt
) {
}

