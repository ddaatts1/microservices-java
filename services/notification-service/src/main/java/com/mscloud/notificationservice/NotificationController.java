package com.mscloud.notificationservice;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);

    private final NotificationRepository notifications;

    public NotificationController(NotificationRepository notifications) {
        this.notifications = notifications;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("service", "notification-service", "status", "UP");
    }

    @PostMapping("/test")
    public NotificationRecord sendTest(@Valid @RequestBody TestNotificationRequest request) {
        NotificationRecord notification = notifications.save(request);
        log.info("event=NotificationRequested notificationId={} to={} subject={}", notification.id(), request.to(), request.subject());
        return notification;
    }

    @GetMapping
    public List<NotificationRecord> findAll() {
        return notifications.findAll();
    }
}
