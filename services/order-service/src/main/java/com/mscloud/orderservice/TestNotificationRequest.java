package com.mscloud.orderservice;

public record TestNotificationRequest(
        String to,
        String subject,
        String message
) {
}

