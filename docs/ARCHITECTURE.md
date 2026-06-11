# Kiến Trúc Java Microservices

## Các Service Trong Workspace

```text
gateway-service       điểm vào public cho local development
user-service          hồ sơ người dùng, map external identity với app user
product-service       CRUD danh mục sản phẩm
order-service         tạo đơn hàng và ghi nhận sự kiện OrderCreated
notification-service  service thông báo, dùng cho email/SMS/push/event consumer
```

## Luồng Request Local

```text
Client
  -> gateway-service :8080
  -> user-service/product-service/order-service/notification-service
```

## Mapping Lên Azure

```text
Azure API Management
  -> Azure Container Apps Environment
      -> gateway-service external
      -> user-service internal
      -> product-service internal
      -> order-service internal
      -> notification-service internal/event consumer

Azure Container Registry lưu Docker image của các service.
Azure Service Bus thay thế event/log nội bộ khi chạy cloud.
Azure Database for PostgreSQL thay PostgreSQL local trong Docker Compose.
Azure Key Vault lưu secret.
Application Insights thu log, trace và metric.
```
