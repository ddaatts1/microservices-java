. (Join-Path $PSScriptRoot "common.ps1")

# Tạo/cập nhật hạ tầng Azure dùng chung cho toàn bộ microservices.
# Script có thể chạy lại nhiều lần; resource đã tồn tại thì bỏ qua hoặc cập nhật an toàn.

Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-NotPlaceholderPassword $PostgresAdminPassword
Ensure-ContainerAppsExtension

Write-Host "Creating Azure resource group and platform resources..."

function Test-AzResourceExists {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$Command
  )

  # Dùng để kiểm tra resource đã tồn tại trước khi tạo mới.
  $result = Invoke-QuietNative $Command
  return $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result.Output -join ""))
}

# Tạo Resource Group: đây là "nhóm" chứa toàn bộ resource của hệ thống.
# $ResourceGroup và $Location được lấy từ infra/azure/env.ps1 qua Import-DeployConfig.
# 1>$null ẩn JSON output thành công để log chỉ còn thông tin quan trọng.
az group create `
  --name $ResourceGroup `
  --location $Location `
  --only-show-errors 1>$null

# Đăng ký resource provider để subscription biết và cho phép tạo các loại dịch vụ bên dưới.
# Lần đầu dùng một dịch vụ Azure trong subscription thường cần bước register này.
az provider register --namespace Microsoft.App --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.OperationalInsights --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.ContainerRegistry --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.DBforPostgreSQL --wait --only-show-errors 1>$null

if (-not (Test-AzResourceExists { az acr show --name $AcrName --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  # ACR lưu image của từng service trước khi Container Apps pull về chạy.
  az acr create `
    --resource-group $ResourceGroup `
    --name $AcrName `
    --sku Basic `
    --location $Location `
    --only-show-errors 1>$null
}

if (-not (Test-AzResourceExists { az monitor log-analytics workspace show --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --query customerId -o tsv --only-show-errors })) {
  # Log Analytics nhận log/runtime signal từ Container Apps Environment.
  az monitor log-analytics workspace create `
    --resource-group $ResourceGroup `
    --workspace-name $LogAnalyticsWorkspace `
    --location $Location `
    --only-show-errors 1>$null
}

$workspaceId = az monitor log-analytics workspace show `
  --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace `
  --query customerId `
  -o tsv

# Container Apps Environment cần workspace id/key để gửi log vào Log Analytics.
$workspaceKey = az monitor log-analytics workspace get-shared-keys `
  --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace `
  --query primarySharedKey `
  -o tsv

if (-not (Test-AzResourceExists { az containerapp env show --name $ContainerAppsEnv --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  # Container Apps Environment là môi trường mạng/log chung cho các app container.
  az containerapp env create `
    --name $ContainerAppsEnv `
    --resource-group $ResourceGroup `
    --location $Location `
    --logs-workspace-id $workspaceId `
    --logs-workspace-key $workspaceKey `
    --only-show-errors 1>$null
}

if (-not (Test-AzResourceExists { az identity show --name $UserAssignedIdentity --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  # Managed Identity giúp Container Apps pull image từ ACR mà không cần username/password.
  az identity create `
    --name $UserAssignedIdentity `
    --resource-group $ResourceGroup `
    --location $Location `
    --only-show-errors 1>$null
}

$identityPrincipalId = az identity show `
  --name $UserAssignedIdentity `
  --resource-group $ResourceGroup `
  --query principalId `
  -o tsv

$acrId = az acr show `
  --name $AcrName `
  --resource-group $ResourceGroup `
  --query id `
  -o tsv

# Gán quyền AcrPull cho Managed Identity để app có quyền kéo image từ ACR.
# Nếu role đã tồn tại thì stderr bị bỏ qua để script có thể chạy lại an toàn.
az role assignment create `
  --assignee-object-id $identityPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role AcrPull `
  --scope $acrId `
  --only-show-errors 1>$null 2>$null

if (-not (Test-AzResourceExists { az postgres flexible-server show --name $PostgresServerName --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  # PostgreSQL Flexible Server là database managed dùng chung, tách database theo service.
  # --public-access 0.0.0.0 cho phép Azure services truy cập trong giai đoạn dev/test.
  az postgres flexible-server create `
    --resource-group $ResourceGroup `
    --name $PostgresServerName `
    --location $Location `
    --admin-user $PostgresAdminUser `
    --admin-password $PostgresAdminPassword `
    --version $PostgresVersion `
    --sku-name $PostgresSku `
    --tier $PostgresTier `
    --storage-size 32 `
    --public-access 0.0.0.0 `
    --only-show-errors 1>$null
}

function Ensure-PostgresFirewallRule {
  # Hỗ trợ cả cú pháp Azure CLI cũ và mới để script chạy ổn trên nhiều máy.
  $helpText = (az postgres flexible-server firewall-rule create -h 2>&1) -join "`n"

  if ($helpText -match "--server-name") {
    az postgres flexible-server firewall-rule create `
      --resource-group $ResourceGroup `
      --server-name $PostgresServerName `
      --name AllowAzureDevTest `
      --start-ip-address 0.0.0.0 `
      --end-ip-address 255.255.255.255 `
      --only-show-errors 1>$null 2>$null
    return
  }

  az postgres flexible-server firewall-rule create `
    --resource-group $ResourceGroup `
    --name $PostgresServerName `
    --rule-name AllowAzureDevTest `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 255.255.255.255 `
    --only-show-errors 1>$null 2>$null
}

# Mở truy cập dev/test ban đầu. Production nên đổi sang VNet/private access.
# Rule 0.0.0.0 -> 255.255.255.255 là rộng, chỉ phù hợp demo/dev.
Ensure-PostgresFirewallRule

# Tạo database riêng cho từng service để giữ ranh giới dữ liệu theo microservice.
function Test-PostgresDatabaseExists([string]$DatabaseName) {
  $result = Invoke-QuietNative { az postgres flexible-server db list `
    --resource-group $ResourceGroup `
    --server-name $PostgresServerName `
    --query "[?name=='$DatabaseName'] | length(@)" `
    -o tsv `
    --only-show-errors }

  if ($result.ExitCode -ne 0) {
    return $false
  }

  $countText = (($result.Output -join "")).Trim()
  if ([string]::IsNullOrWhiteSpace($countText)) {
    return $false
  }

  return ([int]$countText -gt 0)
}

function Ensure-PostgresDatabase([string]$DatabaseName) {
  # Tạo database nếu chưa có; thử cả cú pháp CLI mới và cũ.
  if (Test-PostgresDatabaseExists $DatabaseName) {
    return
  }

  $newSyntax = Invoke-QuietNative { az postgres flexible-server db create `
    --resource-group $ResourceGroup `
    --server-name $PostgresServerName `
    --name $DatabaseName `
    --only-show-errors }
  if ($newSyntax.ExitCode -eq 0) {
    return
  }

  $oldSyntax = Invoke-QuietNative { az postgres flexible-server db create `
    --resource-group $ResourceGroup `
    --server-name $PostgresServerName `
    --database-name $DatabaseName `
    --only-show-errors }
  if ($oldSyntax.ExitCode -eq 0) {
    return
  }

  throw "Could not create PostgreSQL database '$DatabaseName'."
}

# Mỗi service có database riêng trong cùng PostgreSQL server để giảm chi phí dev/test
# nhưng vẫn giữ nguyên nguyên tắc "service sở hữu dữ liệu của service đó".
foreach ($db in @("user_db", "product_db", "order_db", "notification_db")) {
  Ensure-PostgresDatabase $db
}

Write-Host "Azure infra ready. Next: run infra/azure/build-push-images.ps1 then infra/azure/deploy-container-apps.ps1"
