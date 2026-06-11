param(
  # Nếu để trống thì build/push tất cả service trong env.ps1.
  # Ví dụ build riêng product-service: -ServicesToDeploy product-service
  [string[]]$ServicesToDeploy = @()
)

. (Join-Path $PSScriptRoot "common.ps1")

# Build và push Docker image của các service lên Azure Container Registry.
# Có thể truyền ServicesToDeploy để chỉ build những service thay đổi.

Import-DeployConfig
Assert-AzureCli
Assert-LoggedInAzure
Assert-AzureSubscriptionAccessible
Assert-DockerDaemon

$repoRoot = Get-RepoRoot

# loginServer có dạng <acr-name>.azurecr.io, dùng làm prefix cho Docker image.
$loginServer = Get-AcrLoginServer $AcrName $ResourceGroup
$selectedServices = if ($ServicesToDeploy.Count -gt 0) { $ServicesToDeploy } else { $Services }

# Đăng nhập ACR để docker push có quyền đẩy image lên registry.
Write-Host "Logging in to Azure Container Registry: $AcrName"
az acr login --name $AcrName --only-show-errors 1>$null

foreach ($service in $selectedServices) {
  # Chặn service lạ để tránh build/push nhầm image ngoài danh sách chuẩn.
  if ($Services -notcontains $service) {
    throw "Unknown service '$service'. Allowed values: $($Services -join ', ')"
  }

  $servicePath = Join-Path (Join-Path $repoRoot "services") $service

  # Image đầy đủ gồm registry/service:tag, ví dụ mscloudacr.azurecr.io/product-service:latest.
  $image = "$loginServer/$service`:$ImageTag"

  if (-not (Test-Path -LiteralPath $servicePath)) {
    throw "Missing service folder: $servicePath"
  }

  Write-Host "Building $image"
  docker build -t $image $servicePath

  # Image tag lấy từ env.ps1 hoặc GitHub Actions, thường là commit SHA.
  Write-Host "Pushing $image"
  docker push $image
}

Write-Host "Images pushed to $loginServer for: $($selectedServices -join ', ')"
