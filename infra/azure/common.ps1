Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Các hàm dùng chung cho toàn bộ script Azure.
# Mục tiêu: kiểm tra môi trường, nạp cấu hình và gom logic gọi Azure CLI.

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Invoke-QuietNative {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$Command
  )

  # Chạy lệnh native như az/docker ở chế độ im lặng để tự kiểm tra exit code.
  # Không để lỗi stderr phá vỡ flow khi script chỉ cần biết lệnh có thành công hay không.
  $oldErrorActionPreference = $ErrorActionPreference
  $hasNativePreference = Test-Path Variable:\PSNativeCommandUseErrorActionPreference
  if ($hasNativePreference) {
    $oldNativePreference = $PSNativeCommandUseErrorActionPreference
  }

  try {
    $ErrorActionPreference = "Continue"
    if ($hasNativePreference) {
      $PSNativeCommandUseErrorActionPreference = $false
    }

    $output = & $Command 2>$null
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = $output
    }
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    if ($hasNativePreference) {
      $PSNativeCommandUseErrorActionPreference = $oldNativePreference
    }
  }
}

function Import-DeployConfig {
  # Nạp env.ps1 và đẩy các biến cấu hình lên scope của script đang gọi.
  $envFile = Join-Path $PSScriptRoot "env.ps1"
  if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing Azure env config: $envFile. Copy infra/azure/env.example.ps1 to infra/azure/env.ps1 and edit values."
  }
  . $envFile

  $names = @(
    "ProjectName",
    "EnvironmentName",
    "Location",
    "ResourceGroup",
    "ContainerAppsEnv",
    "LogAnalyticsWorkspace",
    "UserAssignedIdentity",
    "AcrName",
    "PostgresServerName",
    "PostgresAdminUser",
    "PostgresAdminPassword",
    "PostgresSku",
    "PostgresTier",
    "PostgresVersion",
    "ImageTag",
    "AuthEnabled",
    "AuthIssuerUri",
    "AuthAudience",
    "Services"
  )

  foreach ($name in $names) {
    $value = Get-Variable -Name $name -Scope Local -ErrorAction SilentlyContinue
    if ($null -ne $value) {
      Set-Variable -Name $name -Value $value.Value -Scope 1
      Set-Variable -Name $name -Value $value.Value -Scope Script
    }
  }
}

function Assert-AzureCli {
  # Azure CLI là bắt buộc vì toàn bộ hạ tầng được tạo/cập nhật bằng az command.
  $az = Get-Command az -ErrorAction SilentlyContinue
  if (-not $az) {
    throw "Azure CLI not found. Install Azure CLI, then run az login."
  }
}

function Assert-LoggedInAzure {
  # Chặn sớm nếu chưa đăng nhập, tránh chạy nửa chừng rồi lỗi khó hiểu.
  $result = Invoke-QuietNative { az account show --only-show-errors }
  if ($result.ExitCode -ne 0) {
    throw "Azure CLI is not logged in. Run az login first."
  }
}

function Assert-AzureSubscriptionAccessible {
  # Xác nhận account hiện tại có quyền đọc subscription/resource group.
  $result = Invoke-QuietNative { az group list --query "[0].name" -o tsv --only-show-errors }
  if ($result.ExitCode -ne 0) {
    throw "Azure subscription is not accessible. Run az login and az account set --subscription <subscription-id>."
  }
}

function Assert-DockerCli {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    throw "Docker CLI not found. Install Docker Desktop before building service images."
  }
}

function Assert-DockerDaemon {
  # Build image cần Docker engine đang chạy, không chỉ có docker CLI trong PATH.
  Assert-DockerCli
  $result = Invoke-QuietNative { docker version --format '{{.Server.Version}}' }
  if ($result.ExitCode -ne 0) {
    throw "Docker daemon is not running. Start Docker Desktop before building service images."
  }
}

function Assert-NotPlaceholderPassword([string]$Password) {
  # Không cho deploy khi password PostgreSQL vẫn là placeholder.
  if ([string]::IsNullOrWhiteSpace($Password) -or $Password -like "CHANGE_ME*") {
    throw "PostgresAdminPassword is still a placeholder. Edit infra/azure/env.ps1 before deploying."
  }
}

function Ensure-ContainerAppsExtension {
  # Đảm bảo máy có extension cần thiết để dùng az containerapp.
  az extension add --name containerapp --upgrade --only-show-errors 1>$null
}

function Get-AcrLoginServer([string]$RegistryName, [string]$ResourceGroupName) {
  # Trả về dạng <registry>.azurecr.io để tag/push Docker image.
  return az acr show --name $RegistryName --resource-group $ResourceGroupName --query loginServer -o tsv
}

function Get-PostgresHost([string]$ServerName) {
  # Fallback theo quy ước FQDN của Azure PostgreSQL Flexible Server.
  return "$ServerName.postgres.database.azure.com"
}
