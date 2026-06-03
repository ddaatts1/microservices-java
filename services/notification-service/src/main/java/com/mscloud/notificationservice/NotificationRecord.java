package com.mscloud.notificationservice;

import java.time.Instant;
import java.util.UUID;

public record NotificationRecord(
        UUID id,
        String recipient,
        String subject,
        String message,
        String status,
        Instant createdAt
) {
}

