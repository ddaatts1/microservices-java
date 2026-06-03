. (Join-Path $PSScriptRoot "common.ps1")

# Build va push image cho toan bo services len ACR.
# Dung khi deploy full stack 5 service.
Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-DockerDaemon

$repoRoot = Get-RepoRoot
$loginServer = Get-AcrLoginServer $AcrName $ResourceGroup

Write-Host "Logging in to Azure Container Registry: $AcrName"
az acr login --name $AcrName --only-show-errors 1>$null

foreach ($service in $Services) {
  $servicePath = Join-Path (Join-Path $repoRoot "services") $service
  $image = "$loginServer/$service`:$ImageTag"

  if (-not (Test-Path -LiteralPath $servicePath)) {
    throw "Missing service folder: $servicePath"
  }

  Write-Host "Building $image"
  docker build -t $image $servicePath

  Write-Host "Pushing $image"
  docker push $image
}

Write-Host "All images pushed to $loginServer"
