package com.mscloud.notificationservice;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.util.List;
import java.util.UUID;

@Component
public class NotificationRepository {
    private final JdbcTemplate jdbc;
    private final RowMapper<NotificationRecord> notificationMapper = (rs, rowNum) -> new NotificationRecord(
            rs.getObject("id", UUID.class),
            rs.getString("recipient"),
            rs.getString("subject"),
            rs.getString("message"),
            rs.getString("status"),
            rs.getTimestamp("created_at").toInstant()
    );

    public NotificationRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public NotificationRecord save(TestNotificationRequest request) {
        NotificationRecord notification = new NotificationRecord(
                UUID.randomUUID(),
                request.to(),
                request.subject(),
                request.message(),
                "QUEUED_FOR_LOCAL_LOG",
                java.time.Instant.now()
        );
        jdbc.update(
                """
                INSERT INTO notifications (id, recipient, subject, message, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                notification.id(),
                notification.recipient(),
                notification.subject(),
                notification.message(),
                notification.status(),
                Timestamp.from(notification.createdAt())
        );
        return notification;
    }

    public List<NotificationRecord> findAll() {
        return jdbc.query("SELECT * FROM notifications ORDER BY created_at DESC", notificationMapper);
    }
}
