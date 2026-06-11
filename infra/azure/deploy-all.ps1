# Wrapper deploy toàn hệ thống:
# preflight -> tạo hạ tầng -> build image 5 service -> deploy tất cả Container Apps.
& (Join-Path $PSScriptRoot "test-preflight.ps1")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

. (Join-Path $PSScriptRoot "create-infra.ps1")
. (Join-Path $PSScriptRoot "build-push-images.ps1")
. (Join-Path $PSScriptRoot "deploy-container-apps.ps1")
