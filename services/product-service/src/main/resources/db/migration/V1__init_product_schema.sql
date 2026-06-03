CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  description TEXT,
  stock INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

INSERT INTO products (id, name, price, description, stock, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Azure Hoodie', 39.90, 'Demo product for microservice flow', 25, NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'Cloud Mug', 12.50, 'Small catalog item', 100, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'Microservice Notebook', 8.75, 'Init data stored in PostgreSQL', 60, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

