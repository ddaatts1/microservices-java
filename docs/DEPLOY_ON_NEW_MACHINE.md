# Huong dan deploy tren may moi

Tai lieu nay dung khi copy folder `microservices-java` sang mot may Windows moi va deploy len Azure.

## 1. Copy source sang may moi

Copy nguyen folder:

```text
microservices-java
```

Khong can copy cac folder build cu:

```text
services/*/target
```

Neu folder co file sau, can can than vi co the chua password:

```text
infra/azure/env.ps1
```

Neu deploy tren may cua chinh ban, co the copy `env.ps1`. Neu gui source cho nguoi khac, nen xoa `env.ps1` va chi giu:

```text
infra/azure/env.example.ps1
```

## 2. Cai tool tren may moi

Can cai:

```text
JDK 17
Maven 3.8+
Docker Desktop
Azure CLI
PowerShell
```

Kiem tra nhanh:

```powershell
java -version
mvn -version
docker version
az version
```

Neu Windows dang dung Java cu, set JDK 17 truoc khi build:

```powershell
$env:JAVA_HOME="C:\Program Files\Java\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
java -version
```

## 3. Dang nhap Azure

Mo PowerShell tai folder project:

```powershell
cd "C:\duong-dan-toi\microservices-java"
az login
az account show
```

Neu co nhieu subscription, chon dung subscription:

```powershell
az account set --subscription "<subscription-id-or-name>"
```

## 4. Tao file cau hinh Azure

Neu chua co `infra/azure/env.ps1`, tao moi:

```powershell
.\infra\azure\init-env.ps1
```

Hoac copy tu file mau:

```powershell
Copy-Item .\infra\azure\env.example.ps1 .\infra\azure\env.ps1
notepad .\infra\azure\env.ps1
```

Can kiem tra/sua cac gia tri quan trong trong `env.ps1`:

```text
$Location
$ResourceGroup
$AcrName
$PostgresServerName
$PostgresAdminUser
$PostgresAdminPassword
$ImageTag
```

Luu y:

- `$AcrName` phai la ten global unique, chi gom chu thuong va so.
- `$PostgresServerName` phai la ten global unique tren Azure.
- `$PostgresAdminPassword` khong duoc de gia tri `CHANGE_ME...`.

## 5. Chay preflight truoc khi deploy

Dam bao Docker Desktop dang chay, sau do:

```powershell
.\infra\azure\test-preflight.ps1
```

Neu preflight bao loi:

- Loi Docker: mo Docker Desktop va doi den khi Docker engine ready.
- Loi Azure login/subscription: chay lai `az login` va `az account set`.
- Loi ACR/PostgreSQL name: sua `$AcrName` hoac `$PostgresServerName` trong `infra/azure/env.ps1`.
- Loi password: sua `$PostgresAdminPassword`.

Chi deploy khi preflight da pass.

## 6. Deploy demo 1 service truoc

Nen deploy `product-service` truoc de test duong di co ban:

```powershell
.\infra\azure\deploy-demo-product-service.ps1
```

Script nay se:

```text
Tao Azure resource group
Tao Azure Container Registry
Tao Log Analytics Workspace
Tao Azure Container Apps Environment
Tao Managed Identity
Tao Azure PostgreSQL Flexible Server
Tao database product_db
Build Docker image product-service
Push image len ACR
Deploy Container App product-service-demo
Chay smoke test
```

Neu muon chay tung buoc:

```powershell
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-product-service.ps1
.\infra\azure\deploy-product-service-demo.ps1
.\infra\azure\test-product-service-demo.ps1
```

## 7. Kiem tra demo

Sau khi deploy, script se in ra URL cua `product-service-demo`.

Kiem tra:

```powershell
Invoke-RestMethod https://<product-service-demo-url>/actuator/health
Invoke-RestMethod https://<product-service-demo-url>/api/products
```

Ket qua health mong doi:

```json
{"status":"UP"}
```

## 8. Deploy toan bo 5 service

Khi demo 1 service da OK, deploy toan bo:

```powershell
.\infra\azure\deploy-all.ps1
```

Script nay se tao/cap nhat ha tang, build/push image va deploy:

```text
gateway-service        public/external
user-service           internal
product-service        internal
order-service          internal
notification-service   internal
```

Sau khi xong, script se in ra Gateway URL.

Kiem tra:

```powershell
Invoke-RestMethod https://<gateway-url>/api/health
Invoke-RestMethod https://<gateway-url>/api/products
```

Test user:

```powershell
Invoke-RestMethod `
  -Uri "https://<gateway-url>/api/me" `
  -Headers @{ "X-User-Id" = "user-001"; "X-User-Email" = "user001@example.com" }
```

Tao order:

```powershell
$body = @{ productId = "11111111-1111-1111-1111-111111111111"; quantity = 2 } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "https://<gateway-url>/api/orders" `
  -Headers @{ "X-User-Id" = "user-001"; "X-User-Email" = "user001@example.com" } `
  -ContentType "application/json" `
  -Body $body
```

## 9. Cac Azure service duoc tao

Ban dev/test hien tai dung:

```text
Azure Resource Group
Azure Container Registry
Azure Container Apps Environment
Azure Container Apps
Azure Database for PostgreSQL Flexible Server
Log Analytics Workspace
User-assigned Managed Identity
```

Database mapping:

```text
user-service         -> user_db
product-service      -> product_db
order-service        -> order_db
notification-service -> notification_db
gateway-service      -> khong dung DB
```

## 10. Don dep de tranh ton chi phi

Neu chi demo xong va muon xoa toan bo resource trong resource group:

```powershell
az group delete --name "<resource-group-name>"
```

Kiem tra ten resource group trong:

```text
infra/azure/env.ps1
```

## 11. Luu y truoc production

Ban script hien tai phu hop dev/test/demo. Truoc production nen bo sung:

```text
Private networking cho PostgreSQL
Key Vault thay cho secret truc tiep trong Container Apps
API Management va JWT validation
Service Bus cho event OrderCreated
Application Insights/OpenTelemetry tracing
Alerting va backup policy
```

