# Azure deployment scripts

Thư mục này chứa script để đưa local microservices lên Azure theo kiểu thật hơn Docker Compose:

```text
Docker Compose local
  -> Azure Container Registry
  -> Azure Container Apps từng service riêng
  -> Azure PostgreSQL Flexible Server
```

## 1. Chuẩn bị local

Yêu cầu:

- Azure CLI
- Docker Desktop
- PowerShell 7 hoặc Windows PowerShell
- Azure subscription đã login bằng `az login`

Copy config mẫu:

```powershell
cd "C:\Users\Admin\Desktop\ms cloud\mscloud\microservices-java"
Copy-Item .\infra\azure\env.example.ps1 .\infra\azure\env.ps1
notepad .\infra\azure\env.ps1
```

Hoặc sinh config dev/test với tên resource có suffix và password PostgreSQL ngẫu nhiên:

```powershell
.\infra\azure\init-env.ps1
```

Sửa các giá trị quan trọng:

```text
$AcrName
$PostgresServerName
$PostgresAdminPassword
$Location
```

## 2. Tạo Azure resources

Chạy preflight trước để kiểm tra Docker, Azure subscription, file config và tên resource:

```powershell
.\infra\azure\test-preflight.ps1
```

Nếu preflight pass, tạo Azure resources:

```powershell
.\infra\azure\create-infra.ps1
```

Script tạo/cập nhật:

- Resource Group
- Azure Container Registry
- Log Analytics Workspace
- Azure Container Apps Environment
- User-assigned Managed Identity
- AcrPull role assignment
- Azure Database for PostgreSQL Flexible Server
- Databases: `user_db`, `product_db`, `order_db`, `notification_db`

## 3. Build và push image

```powershell
.\infra\azure\build-push-images.ps1
```

Image được push dạng:

```text
<acr>.azurecr.io/user-service:<tag>
<acr>.azurecr.io/product-service:<tag>
<acr>.azurecr.io/notification-service:<tag>
<acr>.azurecr.io/order-service:<tag>
<acr>.azurecr.io/gateway-service:<tag>
```

Nếu chỉ demo `product-service`:

```powershell
.\infra\azure\build-push-product-service.ps1
```

## 4. Deploy từng service lên Container Apps

```powershell
.\infra\azure\deploy-container-apps.ps1
```

Ingress:

```text
gateway-service        external
user-service           internal
product-service        internal
order-service          internal
notification-service   internal
```

Nếu chỉ demo `product-service`, script deploy một Container App public riêng tên `product-service-demo`:

```powershell
.\infra\azure\deploy-product-service-demo.ps1
.\infra\azure\test-product-service-demo.ps1
```

Database password được đưa vào Container Apps secret:

```text
SPRING_DATASOURCE_PASSWORD=secretref:db-password
```

## 5. Chạy toàn bộ

```powershell
.\infra\azure\deploy-all.ps1
```

`deploy-all.ps1` sẽ tự chạy `test-preflight.ps1` trước khi tạo infra/build image/deploy app.

Chạy riêng demo một microservice:

```powershell
.\infra\azure\deploy-demo-product-service.ps1
```

## 6. GitHub Actions

Workflow nằm ở:

```text
.github/workflows/deploy-azure-container-apps.yml
```

Repository secrets cần có:

```text
AZURE_CREDENTIALS
AZURE_POSTGRES_ADMIN_PASSWORD
```

Repository variables cần có:

```text
PROJECT_NAME
ENVIRONMENT_NAME
AZURE_LOCATION
AZURE_RESOURCE_GROUP
AZURE_CONTAINER_APPS_ENV
AZURE_LOG_ANALYTICS_WORKSPACE
AZURE_USER_ASSIGNED_IDENTITY
AZURE_CONTAINER_REGISTRY
AZURE_POSTGRES_SERVER
AZURE_POSTGRES_ADMIN_USER
AZURE_POSTGRES_SKU
AZURE_POSTGRES_TIER
AZURE_POSTGRES_VERSION
```

## 7. Chưa phải production hardening hoàn chỉnh

Script hiện tại tạo được môi trường Azure deploy thật cho dev/test cloud, nhưng trước production nên bổ sung:

- Private networking cho PostgreSQL.
- Key Vault references thay vì secret trực tiếp trong Container Apps.
- Azure API Management + JWT validation.
- Service Bus thay cho direct call `order-service -> notification-service`.
- Application Insights/OpenTelemetry tracing.
- Alerting và backup policy.
