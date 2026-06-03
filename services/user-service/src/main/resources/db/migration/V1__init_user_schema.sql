CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  external_user_id VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

INSERT INTO users (id, external_user_id, email, display_name, role, status, created_at, updated_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'dev-user-001', 'dev@example.com', 'Dev User', 'CUSTOMER', 'ACTIVE', NOW(), NOW()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin-001', 'admin@example.com', 'Admin User', 'ADMIN', 'ACTIVE', NOW(), NOW())
ON CONFLICT (external_user_id) DO NOTHING;

