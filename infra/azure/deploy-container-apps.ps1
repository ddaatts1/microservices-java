param(
  [string[]]$ServicesToDeploy = @(),
  [string]$RevisionToken = ""
)

. (Join-Path $PSScriptRoot "common.ps1")

# Deploy hoac cap nhat tat ca Container App tren Azure.
# Gateway public, cac service con lai internal.
Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-NotPlaceholderPassword $PostgresAdminPassword
Ensure-ContainerAppsExtension

$loginServer = Get-AcrLoginServer $AcrName $ResourceGroup
$identityId = az identity show --name $UserAssignedIdentity --resource-group $ResourceGroup --query id -o tsv
$postgresHost = az postgres flexible-server show `
  --name $PostgresServerName `
  --resource-group $ResourceGroup `
  --query fullyQualifiedDomainName `
  -o tsv `
  --only-show-errors
if ([string]::IsNullOrWhiteSpace($postgresHost)) {
  $postgresHost = Get-PostgresHost $PostgresServerName
}
if ([string]::IsNullOrWhiteSpace($postgresHost)) {
  throw "Could not resolve PostgreSQL host for server '$PostgresServerName'."
}

$selectedServices = if ($ServicesToDeploy.Count -gt 0) { $ServicesToDeploy } else { $Services }
foreach ($service in $selectedServices) {
  if ($Services -notcontains $service) {
    throw "Unknown service '$service'. Allowed values: $($Services -join ', ')"
  }
}

$authEnabledValue = if (Get-Variable -Name AuthEnabled -ErrorAction SilentlyContinue) { $AuthEnabled } else { "false" }
$authIssuerUriValue = if (Get-Variable -Name AuthIssuerUri -ErrorAction SilentlyContinue) { $AuthIssuerUri } else { "" }
$authAudienceValue = if (Get-Variable -Name AuthAudience -ErrorAction SilentlyContinue) { $AuthAudience } else { "" }

function Test-ShouldDeploy([string]$Name) {
  return $selectedServices -contains $Name
}

function Test-ContainerAppExists([string]$Name) {
  $result = Invoke-QuietNative { az containerapp show --name $Name --resource-group $ResourceGroup --query id -o tsv --only-show-errors }
  return $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result.Output -join ""))
}

function Get-ContainerAppUrl([string]$Name) {
  $fqdn = az containerapp show `
    --name $Name `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn `
    -o tsv
  if ([string]::IsNullOrWhiteSpace($fqdn)) {
    throw "Container App $Name has no ingress FQDN. Check ingress settings."
  }
  return "https://$fqdn"
}

function Upsert-ContainerApp {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][ValidateSet("internal", "external")][string]$Ingress,
    [Parameter(Mandatory=$true)][string[]]$EnvVars,
    [string[]]$Secrets = @(),
    [decimal]$Cpu = 0.5,
    [string]$Memory = "1Gi",
    [int]$MinReplicas = 1,
    [int]$MaxReplicas = 3
  )

  $effectiveEnvVars = $EnvVars
  if (-not [string]::IsNullOrWhiteSpace($RevisionToken)) {
    $effectiveEnvVars = $effectiveEnvVars + @("DEPLOY_REVISION_TOKEN=$RevisionToken")
  }

  if (Test-ContainerAppExists $Name) {
    Write-Host "Updating Container App: $Name"
    if ($Secrets.Count -gt 0) {
      az containerapp secret set `
        --name $Name `
        --resource-group $ResourceGroup `
        --secrets $Secrets `
        --only-show-errors 1>$null
    }

    az containerapp registry set `
      --name $Name `
      --resource-group $ResourceGroup `
      --server $loginServer `
      --identity $identityId `
      --only-show-errors 1>$null

    az containerapp update `
      --name $Name `
      --resource-group $ResourceGroup `
      --image $Image `
      --replace-env-vars $effectiveEnvVars `
      --cpu $Cpu `
      --memory $Memory `
      --min-replicas $MinReplicas `
      --max-replicas $MaxReplicas `
      --only-show-errors 1>$null

    az containerapp ingress enable `
      --name $Name `
      --resource-group $ResourceGroup `
      --type $Ingress `
      --target-port 8080 `
      --transport auto `
      --only-show-errors 1>$null
    return
  }

  Write-Host "Creating Container App: $Name"
  $secretArgs = @()
  if ($Secrets.Count -gt 0) {
    $secretArgs = @("--secrets") + $Secrets
  }

  az containerapp create `
    --name $Name `
    --resource-group $ResourceGroup `
    --environment $ContainerAppsEnv `
    --image $Image `
    --target-port 8080 `
    --ingress $Ingress `
    --revisions-mode single `
    --user-assigned $identityId `
    --registry-identity $identityId `
    --registry-server $loginServer `
    --env-vars $effectiveEnvVars `
    @secretArgs `
    --cpu $Cpu `
    --memory $Memory `
    --min-replicas $MinReplicas `
    --max-replicas $MaxReplicas `
    --only-show-errors 1>$null
}

function DbEnv([string]$DatabaseName) {
  return @(
    "SERVER_PORT=8080",
    "SPRING_PROFILES_ACTIVE=prod",
    "SPRING_DATASOURCE_URL=jdbc:postgresql://${postgresHost}:5432/${DatabaseName}?sslmode=require",
    "SPRING_DATASOURCE_USERNAME=$PostgresAdminUser",
    "SPRING_DATASOURCE_PASSWORD=secretref:db-password"
  )
}

$dbSecret = @("db-password=$PostgresAdminPassword")

if (Test-ShouldDeploy "user-service") {
  Upsert-ContainerApp `
    -Name "user-service" `
    -Image "$loginServer/user-service`:$ImageTag" `
    -Ingress internal `
    -EnvVars (DbEnv "user_db") `
    -Secrets $dbSecret
}

if (Test-ShouldDeploy "product-service") {
  Upsert-ContainerApp `
    -Name "product-service" `
    -Image "$loginServer/product-service`:$ImageTag" `
    -Ingress internal `
    -EnvVars (DbEnv "product_db") `
    -Secrets $dbSecret
}

if (Test-ShouldDeploy "notification-service") {
  Upsert-ContainerApp `
    -Name "notification-service" `
    -Image "$loginServer/notification-service`:$ImageTag" `
    -Ingress internal `
    -EnvVars (DbEnv "notification_db") `
    -Secrets $dbSecret
}

$productUrl = Get-ContainerAppUrl "product-service"
$notificationUrl = Get-ContainerAppUrl "notification-service"

if (Test-ShouldDeploy "order-service") {
  Upsert-ContainerApp `
    -Name "order-service" `
    -Image "$loginServer/order-service`:$ImageTag" `
    -Ingress internal `
    -EnvVars ((DbEnv "order_db") + @(
      "PRODUCT_SERVICE_URL=$productUrl",
      "NOTIFICATION_SERVICE_URL=$notificationUrl"
    )) `
    -Secrets $dbSecret
}

$userUrl = Get-ContainerAppUrl "user-service"
$orderUrl = Get-ContainerAppUrl "order-service"

if (Test-ShouldDeploy "gateway-service") {
  Upsert-ContainerApp `
    -Name "gateway-service" `
    -Image "$loginServer/gateway-service`:$ImageTag" `
    -Ingress external `
    -EnvVars @(
      "SERVER_PORT=8080",
      "SPRING_PROFILES_ACTIVE=prod",
      "USER_SERVICE_URL=$userUrl",
      "PRODUCT_SERVICE_URL=$productUrl",
      "ORDER_SERVICE_URL=$orderUrl",
      "NOTIFICATION_SERVICE_URL=$notificationUrl",
      "AUTH_ENABLED=$authEnabledValue",
      "AUTH_ISSUER_URI=$authIssuerUriValue",
      "AUTH_AUDIENCE=$authAudienceValue"
    )
}

$gatewayUrl = Get-ContainerAppUrl "gateway-service"
Write-Host "Deploy complete for: $($selectedServices -join ', ')"
Write-Host "Gateway URL: $gatewayUrl"
