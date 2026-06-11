param(
  [string]$GatewayUrl
)

. (Join-Path $PSScriptRoot "common.ps1")

# Smoke test cho gateway-service trên Azure Container Apps.
# Gọi các endpoint chính qua gateway và in rõ endpoint nào lỗi.

if ([string]::IsNullOrWhiteSpace($GatewayUrl)) {
  Import-DeployConfig
  Assert-AzureCli
  Assert-LoggedInAzure
  Assert-AzureSubscriptionAccessible

  $fqdn = az containerapp show `
    --name "gateway-service" `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn `
    -o tsv `
    --only-show-errors

  if ([string]::IsNullOrWhiteSpace($fqdn)) {
    throw "Could not resolve gateway-service URL. Pass -GatewayUrl or deploy the gateway first."
  }

  $GatewayUrl = "https://$fqdn"
}

$GatewayUrl = $GatewayUrl.TrimEnd("/")

# Dev headers mô phỏng identity khi AUTH_ENABLED=false.
$headers = @{
  "X-User-Id" = "dev-user-001"
  "X-User-Email" = "dev@example.com"
}

$tests = @(
  @{ Name = "Gateway health"; Method = "GET"; Url = "$GatewayUrl/api/health" },
  @{ Name = "Current user"; Method = "GET"; Url = "$GatewayUrl/api/me"; Headers = $headers },
  @{ Name = "Products"; Method = "GET"; Url = "$GatewayUrl/api/products" },
  @{ Name = "My orders"; Method = "GET"; Url = "$GatewayUrl/api/orders/my"; Headers = $headers },
  @{ Name = "Notification test"; Method = "POST"; Url = "$GatewayUrl/api/notifications/test"; Headers = @{"Content-Type" = "application/json"}; Body = (@{ to = "test@example.com"; subject = "Azure test"; message = "Testing via smoke script" } | ConvertTo-Json) },
  @{ Name = "Create order"; Method = "POST"; Url = "$GatewayUrl/api/orders"; Headers = @{"Content-Type" = "application/json"; "X-User-Id" = "dev-user-001"; "X-User-Email" = "dev@example.com"}; Body = (@{ productId = "11111111-1111-1111-1111-111111111111"; quantity = 1 } | ConvertTo-Json) }
)

foreach ($test in $tests) {
  # Mỗi request được bắt lỗi riêng để thấy toàn bộ tình trạng gateway.
  Write-Host "--- $($test.Name) $($test.Method) $($test.Url)"
  try {
    $params = @{
      Method = $test.Method
      Uri = $test.Url
      TimeoutSec = 60
    }
    if ($test.ContainsKey("Headers")) { $params.Headers = $test.Headers }
    if ($test.ContainsKey("Body")) { $params.Body = $test.Body }

    $result = Invoke-RestMethod @params
    $json = $result | ConvertTo-Json -Depth 10
    if ($json.Length -gt 1200) {
      $json = $json.Substring(0, 1200) + "...TRUNCATED"
    }
    Write-Host "OK $json"
  } catch {
    Write-Host "ERROR $($_.Exception.Message)"
    $hasResponse = $null -ne $_.Exception -and $_.Exception.PSObject.Properties.Match('Response').Count -gt 0
    if ($hasResponse -and $_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      $description = $_.Exception.Response.StatusDescription
      Write-Host "STATUS $status $description"
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        if ($body.Length -gt 2000) {
          $body = $body.Substring(0, 2000) + "...TRUNCATED"
        }
        Write-Host "BODY $body"
      } catch {
        Write-Host "BODY_READ_FAILED $($_.Exception.Message)"
      }
    }
  }
}
