# Azure deployment status

## Trạng thái hiện tại

Project hiện tại đã có **Azure deploy-ready layer cơ bản** nhưng chưa chạy thật trên subscription trong máy này. Nó đã sẵn sàng ở mức **local microservices MVP + Azure scripts cho dev/test cloud**:

- 5 Spring Boot services build được bằng Maven.
- Dockerfile cho từng service.
- Docker Compose local.
- PostgreSQL local.
- Flyway migration + init data mẫu.
- Giao tiếp service-to-service cơ bản.
- Azure scripts tạo infra, build/push image và deploy từng service riêng lên Container Apps.
- Preflight script kiểm tra Docker, Azure subscription, deploy config và tên resource trước khi deploy.

## Đã có

```text
gateway-service -> user-service
gateway-service -> product-service
gateway-service -> order-service
gateway-service -> notification-service
order-service   -> product-service
order-service   -> notification-service
```

Database local:

```text
user-service         -> user_db
product-service      -> product_db
order-service        -> order_db
notification-service -> notification_db
```

## Đã thêm cho Azure

- `infra/azure/init-env.ps1`
- `infra/azure/test-preflight.ps1`
- `infra/azure/create-infra.ps1`
- `infra/azure/build-push-product-service.ps1`
- `infra/azure/build-push-images.ps1`
- `infra/azure/deploy-product-service-demo.ps1`
- `infra/azure/test-product-service-demo.ps1`
- `infra/azure/deploy-demo-product-service.ps1`
- `infra/azure/deploy-container-apps.ps1`
- `infra/azure/deploy-all.ps1`
- `.github/workflows/deploy-azure-container-apps.yml`

## Blocker hiện tại trước deploy thật

- Docker daemon chưa chạy ổn định, nên chưa build/push image được.
- Azure CLI đang có profile login nhưng subscription hiện tại trả `SubscriptionNotFound` khi truy vấn resource groups.
- Đã sinh `infra/azure/env.ps1` bằng `infra/azure/init-env.ps1`; file này chứa secret cục bộ và đã được `.gitignore`.

## Vẫn chưa có cho production hoàn chỉnh

- Azure Service Bus cho event async.
- Key Vault references thay vì Container Apps direct secrets.
- JWT validation với Auth Provider/API Management.
- Application Insights/OpenTelemetry tracing.
- Private PostgreSQL networking.

## Roadmap deploy Azure

1. Chạy `infra/azure/test-preflight.ps1`.
2. Tạo Azure Database for PostgreSQL hoặc dùng 1 PostgreSQL server tách DB/schema.
3. Tạo Azure Container Apps Environment.
4. Với demo một service: chạy `build-push-product-service.ps1`, `deploy-product-service-demo.ps1`, `test-product-service-demo.ps1`.
5. Với demo toàn hệ: build image cho từng service.
6. Push image lên Azure Container Registry.
7. Deploy `user-service`, `product-service`, `order-service`, `notification-service` internal.
8. Deploy `gateway-service` external.
9. Chuyển password/connection string vào Key Vault hoặc Container Apps secrets.
10. Thêm API Management/Auth Provider/JWT validation.
11. Thêm Service Bus cho `OrderCreated`.
12. Thêm GitHub Actions để build/push/deploy tự động.
