. (Join-Path $PSScriptRoot "common.ps1")
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

  $result = Invoke-QuietNative $Command
  return $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result.Output -join ""))
}

az group create `
  --name $ResourceGroup `
  --location $Location `
  --only-show-errors 1>$null

az provider register --namespace Microsoft.App --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.OperationalInsights --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.ContainerRegistry --wait --only-show-errors 1>$null
az provider register --namespace Microsoft.DBforPostgreSQL --wait --only-show-errors 1>$null

if (-not (Test-AzResourceExists { az acr show --name $AcrName --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  az acr create `
    --resource-group $ResourceGroup `
    --name $AcrName `
    --sku Basic `
    --location $Location `
    --only-show-errors 1>$null
}

if (-not (Test-AzResourceExists { az monitor log-analytics workspace show --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --query customerId -o tsv --only-show-errors })) {
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

$workspaceKey = az monitor log-analytics workspace get-shared-keys `
  --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace `
  --query primarySharedKey `
  -o tsv

if (-not (Test-AzResourceExists { az containerapp env show --name $ContainerAppsEnv --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
  az containerapp env create `
    --name $ContainerAppsEnv `
    --resource-group $ResourceGroup `
    --location $Location `
    --logs-workspace-id $workspaceId `
    --logs-workspace-key $workspaceKey `
    --only-show-errors 1>$null
}

if (-not (Test-AzResourceExists { az identity show --name $UserAssignedIdentity --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
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

az role assignment create `
  --assignee-object-id $identityPrincipalId `
  --assignee-principal-type ServicePrincipal `
  --role AcrPull `
  --scope $acrId `
  --only-show-errors 1>$null 2>$null

if (-not (Test-AzResourceExists { az postgres flexible-server show --name $PostgresServerName --resource-group $ResourceGroup --query id -o tsv --only-show-errors })) {
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
  # Azure CLI 2.84 warns that --rule-name will be removed and newer CLI versions
  # move the server name to --server-name. Keep both paths so new machines work.
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

# Initial dev/test cloud access. Tighten this with VNet/private access before production.
Ensure-PostgresFirewallRule

# Tao database rieng cho tung service.
# Azure CLI co thay doi syntax o phien ban moi, nen thu ca 2 kieu
# de script chay duoc tren may cu va may moi.
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

foreach ($db in @("user_db", "product_db", "order_db", "notification_db")) {
  Ensure-PostgresDatabase $db
}

Write-Host "Azure infra ready. Next: run infra/azure/build-push-images.ps1 then infra/azure/deploy-container-apps.ps1"
