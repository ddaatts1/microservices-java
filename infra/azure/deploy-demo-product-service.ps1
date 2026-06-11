# Wrapper demo một service:
# preflight -> tạo hạ tầng -> build/push product-service -> deploy -> smoke test.
& (Join-Path $PSScriptRoot "test-preflight.ps1")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

. (Join-Path $PSScriptRoot "create-infra.ps1")
. (Join-Path $PSScriptRoot "build-push-product-service.ps1")
. (Join-Path $PSScriptRoot "deploy-product-service-demo.ps1")

& (Join-Path $PSScriptRoot "test-product-service-demo.ps1")
