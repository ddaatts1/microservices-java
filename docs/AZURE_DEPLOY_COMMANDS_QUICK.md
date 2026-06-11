# Lệnh deploy Azure nhanh

File này dùng trên máy mới sau khi copy folder `microservices-java`.

Các file `infra/azure/*.ps1` là script tự động chạy command theo từng bước, để bạn khỏi copy-paste từng lệnh tay.

## 0. Mở đúng terminal

Nên chạy bằng **PowerShell**, không chạy bằng CMD, vì các script deploy là file `.ps1`.

Nếu đang ở CMD, có thể chuyển sang PowerShell bằng lệnh:

```cmd
powershell
```

Sau đó chạy tiếp các lệnh bên dưới.

## 1. Kiểm tra tool

Chạy PowerShell:

```powershell
java -version
mvn -version
docker version
az version
```

Java 17 hoặc Java 21 đều có thể dùng để verify local. Dockerfile của project sẽ tự build service bằng Java 17 khi deploy container.

Nếu muốn ép dùng JDK 17 local, set tạm thời:

```powershell
$env:JAVA_HOME="C:\Program Files\Java\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
java -version
```

Nếu gặp lỗi:

```text
'az' is not recognized as an internal or external command
```

thì máy chưa có Azure CLI hoặc Azure CLI chưa nằm trong PATH. Cài Azure CLI bằng WinGet:

```powershell
winget install --exact --id Microsoft.AzureCLI
```

Sau khi cài xong, **đóng terminal hiện tại, mở PowerShell mới**, rồi verify lại:

```powershell
az version
```

Nếu không dùng được `winget`, tải Azure CLI MSI từ Microsoft Learn:

```text
https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
```

## 2. Vào folder project

Sửa lại đường dẫn theo máy mới:

```powershell
cd "C:\duong-dan-toi\microservices-java"
```

## 3. Verify source local

```powershell
mvn test
docker compose config
```

## 4. Đăng nhập Azure

```powershell
az login
az account show
```

Nếu cần chọn subscription:

```powershell
az account list -o table
az account set --subscription "<subscription-id-or-name>"
az account show
```

Nếu `az login` báo lỗi MFA như:

```text
AADSTS50076: ... you must use multi-factor authentication ...
No subscriptions found
```

thì đăng nhập lại theo tenant cụ thể. Lấy `TENANT_ID` từ lỗi CLI hoặc trong Azure Portal ở phần tenant/directory:

```powershell
az account clear
az config set core.enable_broker_on_windows=false
az config set core.login_experience_v2=off
az login --tenant "<TENANT_ID>" --use-device-code
```

Ví dụ nếu lỗi hiển thị tenant `289e0472-48f5-4573-a3e8-8f00f88489c4`:

```powershell
az account clear
az config set core.enable_broker_on_windows=false
az config set core.login_experience_v2=off
az login --tenant "289e0472-48f5-4573-a3e8-8f00f88489c4" --use-device-code
```

Khi PowerShell hiện mã đăng nhập, mở link được in ra, nhập mã, chọn đúng account và hoàn tất MFA.

Sau đó verify subscription:

```powershell
az account list --all -o table
az account set --subscription "<subscription-id-or-name>"
az account show -o table
```

Lưu ý: tham số đúng là `--all`, không có khoảng trắng. Không gõ `-- all`.

Nếu chỉ có một subscription và `az account show -o table` đã hiện đúng subscription `Enabled`, có thể bỏ qua lệnh `az account set`.

Nếu `az account list --all -o table` vẫn trống dù Portal thấy subscription:

```text
1. Kiểm tra bạn có đăng nhập đúng account trong Azure CLI không.
2. Kiểm tra Portal đang ở đúng Directory/Tenant không.
3. Kiểm tra account có quyền trên subscription không: Subscription > Access control (IAM).
4. Nếu account chưa có quyền, cần Owner/User Access Administrator gán ít nhất Contributor cho account đó.
```

Chưa thấy subscription trong `az account show` thì chưa chạy tiếp deploy.

## 5. Tạo config Azure

Nếu chưa có `infra/azure/env.ps1`:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\infra\azure\init-env.ps1
```

Nếu `env.ps1` đã có sẵn thì không cần chạy lại bước này. Chỉ mở file để sửa:

```powershell
notepad .\infra\azure\env.ps1
```

Nếu thật sự muốn tạo lại file config mới, dùng:

```powershell
.\infra\azure\init-env.ps1 -Force
```

Mở file config để xem/sửa:

```powershell
notepad .\infra\azure\env.ps1
```

Cần verify các biến này:

```text
$Location
$ResourceGroup
$AcrName
$PostgresServerName
$PostgresAdminUser
$PostgresAdminPassword
$ImageTag
```

Lưu ý:

```text
$AcrName: chỉ dùng chữ thường và số, phải unique toàn Azure
$PostgresServerName: phải unique toàn Azure
$PostgresAdminPassword: không được để CHANGE_ME
```

Nếu gặp lỗi:

```text
running scripts is disabled on this system
```

thì chạy **đúng 2 lệnh riêng biệt** trong cùng terminal:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\infra\azure\init-env.ps1
```

Lệnh `Set-ExecutionPolicy -Scope Process` chỉ mở quyền cho phiên PowerShell hiện tại, không đổi cấu hình máy lâu dài.

Nếu muốn một lệnh duy nhất, dùng:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\azure\init-env.ps1
```

## 6. Preflight trước deploy

Mở Docker Desktop trước, đợi Docker engine ready, rồi chạy:

```powershell
.\infra\azure\test-preflight.ps1
```

Nếu preflight chỉ báo warning về kiểm tra tên PostgreSQL thì có thể tiếp tục, vì file config đã sinh tên có hậu tố random.

## 7. Thứ tự deploy demo 1 service

Thứ tự đúng để demo `product-service` là:

```powershell
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-product-service.ps1
.\infra\azure\deploy-product-service-demo.ps1
.\infra\azure\test-product-service-demo.ps1
```

Hoặc chạy một lệnh gọn:

```powershell
.\infra\azure\deploy-demo-product-service.ps1
```

Lệnh gọn này làm cùng một luồng ở trên.

Lấy URL demo nếu cần:

```powershell
. .\infra\azure\env.ps1
$fqdn = az containerapp show --name "product-service-demo" --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv
$productDemoUrl = "https://$fqdn"
$productDemoUrl
Invoke-RestMethod "$productDemoUrl/actuator/health"
Invoke-RestMethod "$productDemoUrl/api/products"
```

## 8. Thứ tự deploy toàn bộ 5 service

Thứ tự đúng để deploy đủ 5 service là:

```powershell
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-images.ps1
.\infra\azure\deploy-container-apps.ps1
```

Hoặc chạy một lệnh gọn:

```powershell
.\infra\azure\deploy-all.ps1
```

Lệnh gọn này làm cùng một luồng ở trên.

Lấy Gateway URL:

```powershell
. .\infra\azure\env.ps1
$fqdn = az containerapp show --name "gateway-service" --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv
$gatewayUrl = "https://$fqdn"
$gatewayUrl
```

Verify gateway:

```powershell
Invoke-RestMethod "$gatewayUrl/api/health"
Invoke-RestMethod "$gatewayUrl/api/products"
```

Verify user:

```powershell
Invoke-RestMethod `
  -Uri "$gatewayUrl/api/me" `
  -Headers @{ "X-User-Id" = "user-001"; "X-User-Email" = "user001@example.com" }
```

Verify tạo order:

```powershell
$body = @{ productId = "11111111-1111-1111-1111-111111111111"; quantity = 2 } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$gatewayUrl/api/orders" `
  -Headers @{ "X-User-Id" = "user-001"; "X-User-Email" = "user001@example.com" } `
  -ContentType "application/json" `
  -Body $body
```

Verify danh sách order:

```powershell
Invoke-RestMethod `
  -Uri "$gatewayUrl/api/orders/my" `
  -Headers @{ "X-User-Id" = "user-001" }
```

Verify notification:

```powershell
$notify = @{ to = "user001@example.com"; subject = "Hello"; message = "Test notification" } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$gatewayUrl/api/notifications/test" `
  -ContentType "application/json" `
  -Body $notify
```

## 9. Verify resource trên Azure

```powershell
. .\infra\azure\env.ps1
az group show --name $ResourceGroup -o table
az acr show --name $AcrName --resource-group $ResourceGroup -o table
az postgres flexible-server show --name $PostgresServerName --resource-group $ResourceGroup -o table
az containerapp list --resource-group $ResourceGroup -o table
```

Verify database:

```powershell
az postgres flexible-server db list `
  --resource-group $ResourceGroup `
  --server-name $PostgresServerName `
  -o table
```

Xem logs nếu app lỗi:

```powershell
az containerapp logs show --name "gateway-service" --resource-group $ResourceGroup --follow
az containerapp logs show --name "product-service" --resource-group $ResourceGroup --follow
az containerapp logs show --name "order-service" --resource-group $ResourceGroup --follow
```

Nếu log của `product-service` có `Connection refused` khi vào PostgreSQL, thì:

```text
1. Copy lại bản mới nhất của `infra/azure/create-infra.ps1` sang máy kia.
2. Chạy lại `.\infra\azure\create-infra.ps1` để tạo DB.
3. Chạy lại `.\infra\azure\deploy-product-service-demo.ps1`.
4. Chạy lại `.\infra\azure\test-product-service-demo.ps1`.
```

Nếu vẫn lỗi, chạy các lệnh verify DB:

```powershell
. .\infra\azure\env.ps1

az postgres flexible-server show `
  --resource-group $ResourceGroup `
  --name $PostgresServerName `
  --query "{name:name,state:state,host:fullyQualifiedDomainName,publicNetworkAccess:network.publicNetworkAccess}" `
  -o json

az postgres flexible-server firewall-rule list `
  --resource-group $ResourceGroup `
  --name $PostgresServerName `
  -o table

az postgres flexible-server db list `
  --resource-group $ResourceGroup `
  --server-name $PostgresServerName `
  -o table

az containerapp show `
  --name "product-service-demo" `
  --resource-group $ResourceGroup `
  --query "properties.template.containers[0].env" `
  -o table
```

Nếu PostgreSQL state không phải `Ready`, đợi hoặc kiểm tra server trên Azure Portal. Nếu thiếu `product_db`, chạy lại `create-infra.ps1` bản mới nhất.

Nếu `SPRING_DATASOURCE_URL` đang bị thiếu host, ví dụ:

```text
jdbc:postgresql:///product_db?sslmode=require
```

thì sửa ngay env var của Container App:

```powershell
. .\infra\azure\env.ps1
$postgresHost = "$PostgresServerName.postgres.database.azure.com"
az containerapp secret set --name "product-service-demo" --resource-group $ResourceGroup --secrets "db-password=$PostgresAdminPassword"
az containerapp update --name "product-service-demo" --resource-group $ResourceGroup --set-env-vars "SERVER_PORT=8080" "SPRING_PROFILES_ACTIVE=prod" "SPRING_DATASOURCE_URL=jdbc:postgresql://$postgresHost:5432/product_db?sslmode=require" "SPRING_DATASOURCE_USERNAME=$PostgresAdminUser" "SPRING_DATASOURCE_PASSWORD=secretref:db-password"
az containerapp update --name "product-service-demo" --resource-group $ResourceGroup --replace-env-vars "SERVER_PORT=8080" "SPRING_PROFILES_ACTIVE=prod" "SPRING_DATASOURCE_URL=jdbc:postgresql://$postgresHost:5432/product_db?sslmode=require" "SPRING_DATASOURCE_USERNAME=$PostgresAdminUser" "SPRING_DATASOURCE_PASSWORD=secretref:db-password"
.\infra\azure\test-product-service-demo.ps1
```

## 10. Dọn dẹp sau demo

Cẩn thận: lệnh này xóa toàn bộ resource trong resource group.

```powershell
. .\infra\azure\env.ps1
az group delete --name $ResourceGroup
```

## Trạng thái script

Đã check:

```text
infra/azure/*.ps1 parse OK
mvn test OK
docker compose config OK
Dockerfile của 5 service OK
application-prod.yml khớp env vars deploy
```

Đã sửa:

```text
infra/azure/create-infra.ps1: lệnh PostgreSQL firewall tương thích Azure CLI cũ và mới
```

Ghi chú: script hiện tại phù hợp dev/test/demo. PostgreSQL firewall đang mở rộng để Container Apps kết nối được; production nên đổi sang private networking/VNet.
