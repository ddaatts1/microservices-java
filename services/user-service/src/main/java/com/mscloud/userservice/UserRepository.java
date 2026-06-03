package com.mscloud.userservice;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
public class UserRepository {
    private final JdbcTemplate jdbc;
    private final RowMapper<UserProfile> userMapper = (rs, rowNum) -> new UserProfile(
            rs.getObject("id", UUID.class),
            rs.getString("external_user_id"),
            rs.getString("email"),
            rs.getString("display_name"),
            rs.getString("role"),
            rs.getString("status"),
            rs.getTimestamp("created_at").toInstant()
    );

    public UserRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public UserProfile findOrCreate(String externalUserId, String email) {
        Optional<UserProfile> existingUser = findByExternalUserId(externalUserId);
        if (existingUser.isPresent()) {
            return existingUser.get();
        }

        Instant now = Instant.now();
        jdbc.update(
                """
                INSERT INTO users (id, external_user_id, email, display_name, role, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (external_user_id) DO NOTHING
                """,
                UUID.randomUUID(),
                externalUserId,
                email,
                displayNameFromEmail(email),
                "CUSTOMER",
                "ACTIVE",
                Timestamp.from(now),
                Timestamp.from(now)
        );
        return findByExternalUserId(externalUserId).orElseThrow();
    }

    public Optional<UserProfile> findById(UUID id) {
        return jdbc.query("SELECT * FROM users WHERE id = ?", userMapper, id).stream().findFirst();
    }

    public Optional<UserProfile> findByExternalUserId(String externalUserId) {
        return jdbc.query("SELECT * FROM users WHERE external_user_id = ?", userMapper, externalUserId).stream().findFirst();
    }

    public List<UserProfile> findAll() {
        return jdbc.query("SELECT * FROM users ORDER BY created_at DESC", userMapper);
    }

    private String displayNameFromEmail(String email) {
        if (email == null || email.isBlank() || !email.contains("@")) {
            return "Dev User";
        }
        return email.substring(0, email.indexOf('@'));
    }
}
