# Java microservices architecture

## Services created in this workspace

```text
gateway-service       public entrypoint for local development
user-service          app user profile, maps external identity to app user
product-service       catalog/product CRUD
order-service         creates orders and logs OrderCreated event
notification-service  placeholder for email/SMS/push/event consumer
```

## Local request flow

```text
Client
  -> gateway-service :8080
  -> user-service/product-service/order-service/notification-service
```

## Later Azure mapping

```text
Azure API Management
  -> Azure Container Apps Environment
      -> gateway-service external
      -> user-service internal
      -> product-service internal
      -> order-service internal
      -> notification-service internal/event consumer

Azure Container Registry stores service images.
Azure Service Bus will replace local log-only events.
Azure Database for PostgreSQL will replace local Docker Compose PostgreSQL.
Azure Key Vault will store secrets.
Application Insights will collect logs/traces/metrics.
```
