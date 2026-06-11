# Copy this file to env.ps1 and change values before running deploy scripts.

# Tên project và môi trường được ghép vào tên resource để dễ nhận diện trên Azure.
$ProjectName = "mscloud"
$EnvironmentName = "dev"

# Azure region nơi tạo resource, ví dụ: southeastasia, eastus, westeurope.
$Location = "southeastasia"

# Các tên bên dưới được tạo theo quy ước:
# rg = Resource Group, cae = Container Apps Environment, log = Log Analytics, id = Managed Identity.
$ResourceGroup = "rg-$ProjectName-$EnvironmentName"
$ContainerAppsEnv = "cae-$ProjectName-$EnvironmentName"
$LogAnalyticsWorkspace = "log-$ProjectName-$EnvironmentName"
$UserAssignedIdentity = "id-$ProjectName-$EnvironmentName"

# ACR lưu Docker image. Tên ACR phải unique toàn Azure, chỉ dùng chữ thường và số.
$AcrName = "mscloudacrdev001"

# PostgreSQL Flexible Server là database managed. Tên server cũng phải unique toàn Azure.
$PostgresServerName = "psql-$ProjectName-$EnvironmentName-001"
$PostgresAdminUser = "mscloudadmin"

# Đổi password này trước khi deploy. Không dùng password placeholder trên Azure thật.
$PostgresAdminPassword = "CHANGE_ME_StrongPassword_123!"

# Cấu hình máy PostgreSQL dev/test tiết kiệm chi phí; production cần sizing lại.
$PostgresSku = "Standard_B1ms"
$PostgresTier = "Burstable"
$PostgresVersion = "16"

# Tag Docker image. Local/demo dùng latest; CI/CD nên dùng commit SHA để dễ rollback.
$ImageTag = "latest"

# Auth tắt mặc định cho local/demo.
# Bật auth sau khi tạo Microsoft Entra External ID app/API registration.
$AuthEnabled = "false"
$AuthIssuerUri = ""
$AuthAudience = ""

# Danh sách service chuẩn được build/deploy. Script sẽ chặn service không nằm trong danh sách này.
$Services = @(
  "user-service",
  "product-service",
  "notification-service",
  "order-service",
  "gateway-service"
)
