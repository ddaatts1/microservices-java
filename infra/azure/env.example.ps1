# Copy this file to env.ps1 and change values before running deploy scripts.

$ProjectName = "mscloud"
$EnvironmentName = "dev"
$Location = "southeastasia"

$ResourceGroup = "rg-$ProjectName-$EnvironmentName"
$ContainerAppsEnv = "cae-$ProjectName-$EnvironmentName"
$LogAnalyticsWorkspace = "log-$ProjectName-$EnvironmentName"
$UserAssignedIdentity = "id-$ProjectName-$EnvironmentName"

# ACR name must be globally unique, lowercase, and alphanumeric only.
$AcrName = "mscloudacrdev001"

# PostgreSQL flexible server name must be globally unique.
$PostgresServerName = "psql-$ProjectName-$EnvironmentName-001"
$PostgresAdminUser = "mscloudadmin"
$PostgresAdminPassword = "CHANGE_ME_StrongPassword_123!"
$PostgresSku = "Standard_B1ms"
$PostgresTier = "Burstable"
$PostgresVersion = "16"

# Used by image build/deploy scripts.
$ImageTag = "latest"

# Auth is disabled by default for local/demo deploy.
# Set these after creating Microsoft Entra External ID app/API registrations.
$AuthEnabled = "false"
$AuthIssuerUri = ""
$AuthAudience = ""

$Services = @(
  "user-service",
  "product-service",
  "notification-service",
  "order-service",
  "gateway-service"
)
