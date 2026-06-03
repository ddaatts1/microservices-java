package com.mscloud.notificationservice;

import jakarta.validation.constraints.NotBlank;

public record TestNotificationRequest(
        @NotBlank String to,
        @NotBlank String subject,
        @NotBlank String message
) {
}

