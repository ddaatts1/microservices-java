param(
  [string]$BaseUrl,
  [int]$MaxWaitSeconds = 600,
  [int]$PollSeconds = 15
)

. (Join-Path $PSScriptRoot "common.ps1")

# Smoke test cho product-service demo: health check và danh sách sản phẩm.
# Nếu không truyền BaseUrl, script tự lấy FQDN từ Container App.

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Import-DeployConfig
  Assert-AzureCli
  Assert-LoggedInAzure
  Assert-AzureSubscriptionAccessible

  $fqdn = az containerapp show `
    --name "product-service-demo" `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn `
    -o tsv `
    --only-show-errors

  if ([string]::IsNullOrWhiteSpace($fqdn)) {
    throw "Could not resolve product-service-demo URL. Pass -BaseUrl or deploy the demo app first."
  }

  $BaseUrl = "https://$fqdn"
}

$BaseUrl = $BaseUrl.TrimEnd("/")

Write-Host "Testing $BaseUrl"

function Wait-ForHealth([string]$Url) {
  # Container App có thể cần vài phút để pull image/startup, nên poll health endpoint.
  $deadline = [DateTime]::UtcNow.AddSeconds($MaxWaitSeconds)
  $attempt = 0
  $lastError = $null

  while ([DateTime]::UtcNow -lt $deadline) {
    $attempt++
    try {
      return Invoke-RestMethod `
        -Method Get `
        -Uri "$Url/actuator/health" `
        -TimeoutSec 30
    } catch {
      $lastError = $_.Exception.Message
      Write-Host "Health check not ready yet (attempt $attempt): $lastError"
      Start-Sleep -Seconds $PollSeconds
    }
  }

  throw "Timed out waiting for $Url/actuator/health after $MaxWaitSeconds seconds. Last error: $lastError"
}

$health = Wait-ForHealth $BaseUrl

# Sau khi health UP, kiểm tra API nghiệp vụ có trả sản phẩm hay không.
$products = Invoke-RestMethod `
  -Method Get `
  -Uri "$BaseUrl/api/products" `
  -TimeoutSec 30

$productCount = 0
if ($null -ne $products) {
  if ($products -is [array]) {
    $productCount = $products.Count
  } else {
    $productCount = 1
  }
}

Write-Host "Health status: $($health.status)"
Write-Host "Products returned: $productCount"
Write-Host "Smoke test passed."
