. (Join-Path $PSScriptRoot "common.ps1")

# Build Docker image cho product-service va push image len Azure Container Registry.
# Script nay dung khi demo 1 service truoc.
Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-DockerDaemon

$repoRoot = Get-RepoRoot
$loginServer = Get-AcrLoginServer $AcrName $ResourceGroup
$service = "product-service"
$servicePath = Join-Path (Join-Path $repoRoot "services") $service
$image = "$loginServer/$service`:$ImageTag"

if (-not (Test-Path -LiteralPath $servicePath)) {
  throw "Missing service folder: $servicePath"
}

Write-Host "Logging in to Azure Container Registry: $AcrName"
az acr login --name $AcrName --only-show-errors 1>$null

Write-Host "Building $image"
docker build -t $image $servicePath

Write-Host "Pushing $image"
docker push $image

Write-Host "Product service image pushed: $image"
