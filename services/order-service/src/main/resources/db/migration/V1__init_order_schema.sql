CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY,
  external_user_id VARCHAR(255) NOT NULL,
  product_id UUID NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price NUMERIC(12, 2) NOT NULL,
  total_amount NUMERIC(12, 2) NOT NULL,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_external_user_id ON orders (external_user_id);

INSERT INTO orders (id, external_user_id, product_id, product_name, quantity, unit_price, total_amount, status, created_at)
VALUES
  ('99999999-9999-9999-9999-999999999999', 'dev-user-001', '22222222-2222-2222-2222-222222222222', 'Cloud Mug', 1, 12.50, 12.50, 'CREATED', NOW())
ON CONFLICT (id) DO NOTHING;

