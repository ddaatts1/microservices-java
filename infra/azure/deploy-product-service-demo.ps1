. (Join-Path $PSScriptRoot "common.ps1")

# Tao hoac cap nhat Container App demo public cho product-service.
# Script nay lay image tu ACR, gan database va mo ingress external.
Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-NotPlaceholderPassword $PostgresAdminPassword
Ensure-ContainerAppsExtension

$appName = "product-service-demo"
$serviceName = "product-service"
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
$image = "$loginServer/$serviceName`:$ImageTag"

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

$dbSecret = @("db-password=$PostgresAdminPassword")
$envVars = @(
  "SERVER_PORT=8080",
  "SPRING_PROFILES_ACTIVE=prod",
  "SPRING_DATASOURCE_URL=jdbc:postgresql://${postgresHost}:5432/product_db?sslmode=require",
  "SPRING_DATASOURCE_USERNAME=$PostgresAdminUser",
  "SPRING_DATASOURCE_PASSWORD=secretref:db-password"
)

if (Test-ContainerAppExists $appName) {
  Write-Host "Updating Container App: $appName"
  az containerapp secret set `
    --name $appName `
    --resource-group $ResourceGroup `
    --secrets $dbSecret `
    --only-show-errors 1>$null

  az containerapp registry set `
    --name $appName `
    --resource-group $ResourceGroup `
    --server $loginServer `
    --identity $identityId `
    --only-show-errors 1>$null

  az containerapp update `
    --name $appName `
    --resource-group $ResourceGroup `
    --image $image `
    --replace-env-vars $envVars `
    --cpu 0.5 `
    --memory "1Gi" `
    --min-replicas 1 `
    --max-replicas 3 `
    --only-show-errors 1>$null

  az containerapp ingress enable `
    --name $appName `
    --resource-group $ResourceGroup `
    --type external `
    --target-port 8080 `
    --transport auto `
    --only-show-errors 1>$null
} else {
  Write-Host "Creating Container App: $appName"
  az containerapp create `
    --name $appName `
    --resource-group $ResourceGroup `
    --environment $ContainerAppsEnv `
    --image $image `
    --target-port 8080 `
    --ingress external `
    --revisions-mode single `
    --user-assigned $identityId `
    --registry-identity $identityId `
    --registry-server $loginServer `
    --env-vars $envVars `
    --secrets $dbSecret `
    --cpu 0.5 `
    --memory "1Gi" `
    --min-replicas 1 `
    --max-replicas 3 `
    --only-show-errors 1>$null
}

$url = Get-ContainerAppUrl $appName
Write-Host "Product service demo URL: $url"
Write-Host "Smoke test: .\infra\azure\test-product-service-demo.ps1 -BaseUrl `"$url`""
