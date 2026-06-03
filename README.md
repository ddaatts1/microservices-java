# Java Microservices Workspace

Workspace này là bản scaffold đầu tiên cho app microservice Java/Spring Boot.

## Services

| Service | Local port | Vai trò |
|---|---:|---|
| `gateway-service` | `8080` | API entrypoint local, forward request tới service nội bộ |
| `user-service` | `8081` | Profile user, map external identity sang app user |
| `product-service` | `8082` | Catalog/product CRUD dùng PostgreSQL |
| `order-service` | `8083` | Tạo order, gọi product-service, log `OrderCreated` event |
| `notification-service` | `8084` | Placeholder gửi notification/log event |
| `postgres` | `5432` | PostgreSQL local, tách database theo service |

## Yêu cầu

- JDK 17
- Maven 3.8+
- Docker Desktop nếu chạy bằng Docker Compose

Máy hiện có `JAVA_HOME=C:\Program Files\Java\jdk-17`, nhưng `PATH` có thể đang trỏ Java 8. Trước khi build local bằng Maven, chạy:

```powershell
$env:JAVA_HOME="C:\Program Files\Java\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
java -version
```

## Build tất cả service

```powershell
cd "C:\Users\Admin\Desktop\ms cloud\mscloud\microservices-java"
mvn -DskipTests package
```

## Chạy bằng Docker Compose

```powershell
cd "C:\Users\Admin\Desktop\ms cloud\mscloud\microservices-java"
docker compose up --build
```

Docker Compose sẽ tạo PostgreSQL và các database:

```text
user_db
product_db
order_db
notification_db
```

Init database/migration nằm ở:

```text
infra/postgres/init/01-create-databases.sql
services/*/src/main/resources/db/migration/V1__init_*_schema.sql
```

## Test nhanh qua gateway

```powershell
curl http://localhost:8080/api/health
curl http://localhost:8080/api/products
curl -H "X-User-Id: user-001" -H "X-User-Email: user001@example.com" http://localhost:8080/api/me
```

Tạo order:

```powershell
$body = @{ productId = "11111111-1111-1111-1111-111111111111"; quantity = 2 } | ConvertTo-Json
Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:8080/api/orders" `
  -Headers @{ "X-User-Id" = "user-001"; "X-User-Email" = "user001@example.com" } `
  -ContentType "application/json" `
  -Body $body
```

Xem order của user:

```powershell
curl -H "X-User-Id: user-001" http://localhost:8080/api/orders/my
```

Test notification placeholder:

```powershell
$body = @{ to = "user001@example.com"; subject = "Hello"; message = "Test notification" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/notifications/test" -ContentType "application/json" -Body $body
```

## Ghi chú kiến trúc

- Hiện tại các service chính đã dùng PostgreSQL local qua Docker Compose.
- Auth provider chưa tích hợp; gateway đang dùng dev headers `X-User-Id` và `X-User-Email` để mô phỏng identity.
- Giao tiếp service đã có:
  - `gateway-service` gọi `user-service`, `product-service`, `order-service`, `notification-service`.
  - `order-service` gọi `product-service` để lấy product trước khi tạo order.
  - `order-service` gọi `notification-service` sau khi tạo order để mô phỏng event notification.
- Bước tiếp theo nên làm:
  1. Thêm JWT validation ở gateway/API Management.
  2. Thêm Azure Service Bus cho event `OrderCreated` thay vì gọi notification trực tiếp.
  3. Chuyển secrets sang Key Vault references thay vì secret trực tiếp trong Container Apps.
  4. Thêm Application Insights/OpenTelemetry tracing.
  5. Siết private networking cho PostgreSQL trước production.

## Azure deploy-ready layer

Đã có script deploy Azure ở:

```text
infra/azure
```

Demo phục vụ thuyết trình nên đi theo `product-service` trước:

```powershell
.\infra\azure\init-env.ps1
.\infra\azure\test-preflight.ps1
.\infra\azure\deploy-demo-product-service.ps1
```

Luồng này sẽ tạo hạ tầng Azure, build/push riêng image `product-service`, tạo Container App public `product-service-demo`, rồi gọi smoke test qua `/actuator/health` và `/api/products`.

Tài liệu nói kèm:

```text
docs/DEMO_MICROSERVICE_AZURE.md
```

Sau khi người nghe hiểu demo một service, có thể mở rộng sang toàn bộ 5 service.

Thứ tự chạy:

```powershell
.\infra\azure\init-env.ps1
.\infra\azure\test-preflight.ps1
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-images.ps1
.\infra\azure\deploy-container-apps.ps1
```

Hoặc chạy gộp:

```powershell
.\infra\azure\deploy-all.ps1
```

Nên kiểm tra trước bằng:

```powershell
.\infra\azure\test-preflight.ps1
```
