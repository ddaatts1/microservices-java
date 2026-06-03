# Wrapper full stack:
# preflight -> tao infra -> build image cho 5 service -> deploy all apps.
& (Join-Path $PSScriptRoot "test-preflight.ps1")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

. (Join-Path $PSScriptRoot "create-infra.ps1")
. (Join-Path $PSScriptRoot "build-push-images.ps1")
. (Join-Path $PSScriptRoot "deploy-container-apps.ps1")
