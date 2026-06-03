. (Join-Path $PSScriptRoot "common.ps1")

$script:FailureCount = 0
$script:ConfigLoaded = $false
$script:AzureReady = $false

function Write-Pass([string]$Name) {
  Write-Host "[OK] $Name"
}

function Write-Fail([string]$Name, [string]$Message) {
  $script:FailureCount++
  Write-Host "[FAIL] $Name"
  Write-Host "       $Message"
}

function Write-Skip([string]$Name, [string]$Reason) {
  Write-Host "[SKIP] $Name"
  Write-Host "       $Reason"
}

function Invoke-PreflightCheck {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][scriptblock]$Check
  )

  try {
    & $Check
    Write-Pass $Name
  } catch {
    Write-Fail $Name $_.Exception.Message
  }
}

function Assert-CommandExists([string]$CommandName, [string]$InstallHint) {
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "$CommandName not found. $InstallHint"
  }
}

function Assert-DeployConfigValues {
  Assert-NotPlaceholderPassword $PostgresAdminPassword

  if ($AcrName -notmatch '^[a-z0-9]{5,50}$') {
    throw "AcrName must be 5-50 lowercase alphanumeric characters."
  }

  if ($PostgresServerName -notmatch '^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])$') {
    throw "PostgresServerName must be 3-63 chars, lowercase letters/numbers/hyphens, and cannot start or end with hyphen."
  }

  if ([string]::IsNullOrWhiteSpace($Location)) {
    throw "Location is empty."
  }

  if (-not $Services -or $Services.Count -eq 0) {
    throw "Services list is empty."
  }
}

function Assert-ServiceFolders {
  $repoRoot = Get-RepoRoot
  $expected = @(
    "gateway-service",
    "user-service",
    "product-service",
    "order-service",
    "notification-service"
  )

  foreach ($service in $expected) {
    if ($Services -notcontains $service) {
      throw "Services list does not include $service."
    }
  }

  foreach ($service in $Services) {
    $servicePath = Join-Path (Join-Path $repoRoot "services") $service
    $dockerfilePath = Join-Path $servicePath "Dockerfile"
    $pomPath = Join-Path $servicePath "pom.xml"

    if (-not (Test-Path -LiteralPath $servicePath)) {
      throw "Missing service folder: $servicePath"
    }
    if (-not (Test-Path -LiteralPath $dockerfilePath)) {
      throw "Missing Dockerfile: $dockerfilePath"
    }
    if (-not (Test-Path -LiteralPath $pomPath)) {
      throw "Missing Maven pom: $pomPath"
    }
  }
}

function Assert-AcrNameAvailableOrExisting {
  $existingAcr = Invoke-QuietNative { az acr show `
    --name $AcrName `
    --resource-group $ResourceGroup `
    --query id `
    -o tsv `
    --only-show-errors }

  if ($existingAcr.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($existingAcr.Output -join ""))) {
    return
  }

  $available = Invoke-QuietNative { az acr check-name `
    --name $AcrName `
    --query nameAvailable `
    -o tsv `
    --only-show-errors }

  if ($available.ExitCode -ne 0) {
    throw "Could not check ACR name availability."
  }

  if ((($available.Output -join "").Trim()) -ne "true") {
    throw "ACR name '$AcrName' is not globally available. Edit infra/azure/env.ps1."
  }
}

function Assert-PostgresNameAvailableOrExisting {
  $existingServer = Invoke-QuietNative { az postgres flexible-server show `
    --name $PostgresServerName `
    --resource-group $ResourceGroup `
    --query id `
    -o tsv `
    --only-show-errors }

  if ($existingServer.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($existingServer.Output -join ""))) {
    return
  }

  $subscription = Invoke-QuietNative { az account show --query id -o tsv --only-show-errors }
  $subscriptionId = ($subscription.Output -join "").Trim()
  if ($subscription.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw "Could not read Azure subscription id."
  }

  $body = @{
    name = $PostgresServerName
    type = "Microsoft.DBforPostgreSQL/flexibleServers"
  } | ConvertTo-Json -Compress

  $uriCandidates = @(
    "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.DBforPostgreSQL/locations/$Location/checkNameAvailability?api-version=2025-08-01",
    "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.DBforPostgreSQL/checkNameAvailability?api-version=2025-08-01",
    "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.DBforPostgreSQL/checkNameAvailability?api-version=2024-08-01"
  )

  $availability = $null
  $checked = $false

  foreach ($uri in $uriCandidates) {
    $result = Invoke-QuietNative { az rest `
      --method post `
      --uri $uri `
      --body $body `
      --query "{nameAvailable:nameAvailable,reason:reason,message:message}" `
      -o json `
      --only-show-errors }

    if ($result.ExitCode -ne 0) {
      continue
    }

    try {
      $availability = ($result.Output -join "`n") | ConvertFrom-Json
      $checked = $true
      break
    } catch {
      continue
    }
  }

  if (-not $checked) {
    Write-Warning "Could not check PostgreSQL Flexible Server name availability via Azure API. Continuing because the generated server name already includes a random suffix."
    return
  }

  if ($null -ne $availability -and -not $availability.nameAvailable) {
    $detail = $availability.message
    if ([string]::IsNullOrWhiteSpace($detail)) {
      $detail = $availability.reason
    }
    throw "PostgreSQL server name '$PostgresServerName' is not available. $detail"
  }
}

Write-Host "Running Azure Container Apps deploy preflight..."

Invoke-PreflightCheck "PowerShell script root" {
  if (-not (Test-Path -LiteralPath $PSScriptRoot)) {
    throw "Script root does not exist."
  }
}

Invoke-PreflightCheck "Azure CLI installed" {
  Assert-AzureCli
}

Invoke-PreflightCheck "Docker CLI installed" {
  Assert-DockerCli
}

Invoke-PreflightCheck "Docker daemon running" {
  Assert-DockerDaemon
}

Invoke-PreflightCheck "Maven installed" {
  Assert-CommandExists "mvn" "Install Maven or use the Docker build path for image builds."
}

Invoke-PreflightCheck "Azure login and subscription access" {
  Assert-LoggedInAzure
  Assert-AzureSubscriptionAccessible
  $script:AzureReady = $true
}

Invoke-PreflightCheck "Azure deploy config" {
  Import-DeployConfig
  Assert-DeployConfigValues
  $script:ConfigLoaded = $true
}

if ($script:ConfigLoaded) {
  Invoke-PreflightCheck "Service folders and Dockerfiles" {
    Assert-ServiceFolders
  }
} else {
  Write-Skip "Service folders and Dockerfiles" "Deploy config did not load."
}

if ($script:ConfigLoaded -and $script:AzureReady) {
  Invoke-PreflightCheck "ACR name availability" {
    Assert-AcrNameAvailableOrExisting
  }

  Invoke-PreflightCheck "PostgreSQL server name availability" {
    Assert-PostgresNameAvailableOrExisting
  }
} else {
  Write-Skip "ACR name availability" "Azure access or deploy config is not ready."
  Write-Skip "PostgreSQL server name availability" "Azure access or deploy config is not ready."
}

if ($script:FailureCount -gt 0) {
  Write-Host "Preflight failed with $script:FailureCount issue(s)."
  exit 1
}

Write-Host "Preflight passed. You can run infra/azure/deploy-all.ps1."
