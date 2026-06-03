CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY,
  recipient VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

INSERT INTO notifications (id, recipient, subject, message, status, created_at)
VALUES
  ('88888888-8888-8888-8888-888888888888', 'dev@example.com', 'Welcome', 'Seed notification from PostgreSQL init data', 'QUEUED_FOR_LOCAL_LOG', NOW())
ON CONFLICT (id) DO NOTHING;

