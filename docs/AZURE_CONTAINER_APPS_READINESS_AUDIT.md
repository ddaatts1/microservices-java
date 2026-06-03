# Azure Container Apps readiness audit

Date: 2026-05-29

## Source material reviewed

- `C:\Users\Admin\Desktop\ms cloud\mscloud\TLTT_Nhom1.pptx`
- `C:\Users\Admin\Desktop\ms cloud\mscloud\microservices-java`

## PowerPoint summary

The deck has 36 slides. Its current story is:

- Cloud Computing overview, Azure basics, Azure Portal/CLI/PowerShell/SDK/API.
- Azure App Service: PaaS model, App Service Plan, manual deploy, CI/CD deploy.
- Azure Kubernetes Service: Kubernetes concepts, AKS architecture and benefits.
- CI/CD on Azure with Azure DevOps/GitHub Actions.
- Demo section currently targets Product Service on Azure App Service, not Azure Container Apps.

For the microservices repo, the deploy story should be adjusted from single Product Service/App Service to multi-service Container Apps:

```text
Client
  -> gateway-service       external Container App
  -> user-service          internal Container App
  -> product-service       internal Container App
  -> order-service         internal Container App
  -> notification-service  internal Container App
  -> Azure Database for PostgreSQL Flexible Server
```

## Current implementation

Services:

| Service | Role | Database |
|---|---|---|
| `gateway-service` | Public API entrypoint and local reverse proxy | None |
| `user-service` | User profile from dev identity headers | `user_db` |
| `product-service` | Product catalog CRUD | `product_db` |
| `order-service` | Order creation, product lookup, notification call | `order_db` |
| `notification-service` | Notification placeholder/log API | `notification_db` |

Deploy assets already present:

- Dockerfile for each service.
- `docker-compose.yml` for local PostgreSQL and all services.
- Flyway migrations under `services/*/src/main/resources/db/migration`.
- Azure scripts under `infra/azure`:
  - `init-env.ps1`
  - `test-preflight.ps1`
  - `create-infra.ps1`
  - `build-push-product-service.ps1`
  - `build-push-images.ps1`
  - `deploy-product-service-demo.ps1`
  - `test-product-service-demo.ps1`
  - `deploy-demo-product-service.ps1`
  - `deploy-container-apps.ps1`
  - `deploy-all.ps1`
- GitHub Actions workflow:
  - `.github/workflows/deploy-azure-container-apps.yml`

## Verification performed

Passed:

- `mvn -DskipTests package`
- `mvn test`
- `docker compose config`
- PowerShell parser check for `infra/azure/*.ps1`

Notes:

- Maven uses JDK 17 through `JAVA_HOME`.
- Plain `java -version` still resolves to Java 8 from PATH, so set `JAVA_HOME` and prepend `JAVA_HOME\bin` before manual `java -jar` runs.
- Docker CLI and Docker Compose are installed.
- Azure CLI is installed.
- `infra/azure/test-preflight.ps1` now checks Docker, Azure subscription access, deploy config, service folders, ACR name availability, and PostgreSQL Flexible Server name availability.

Not verified yet:

- Docker image build/push, because Docker daemon is not running.
- Actual Azure resource creation/deploy, because the current Azure CLI subscription lookup returns `SubscriptionNotFound`.
- ACR/PostgreSQL global name availability, because Azure subscription access is not working yet.

## Deploy readiness status

The repo is ready at source/config level for a dev/test Azure Container Apps deployment, but not yet proven running in Azure.

Immediate blockers before running `infra/azure/deploy-all.ps1`:

1. Start Docker Desktop so `docker build` and `docker push` can run.
2. Fix Azure CLI subscription access, then confirm `az group list` succeeds.
3. Verify ACR/PostgreSQL names are globally available before creating resources.

Recommended sequence after blockers are cleared:

```powershell
cd "C:\Users\Admin\Desktop\ms cloud\mscloud\microservices-java"
.\infra\azure\test-preflight.ps1
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-product-service.ps1
.\infra\azure\deploy-product-service-demo.ps1
.\infra\azure\test-product-service-demo.ps1
```

Smoke tests after deploy:

```powershell
Invoke-RestMethod https://<gateway-fqdn>/api/health
Invoke-RestMethod https://<gateway-fqdn>/api/products
Invoke-RestMethod https://<gateway-fqdn>/api/me -Headers @{
  "X-User-Id" = "user-001"
  "X-User-Email" = "user001@example.com"
}
```

## Production gaps

- No JWT validation yet; identity is still simulated by `X-User-Id` and `X-User-Email`.
- `order-service` still calls `notification-service` directly; Azure Service Bus should replace this for async event flow.
- Secrets are currently modeled as Container Apps secrets; Key Vault references are better for production.
- PostgreSQL is currently scripted with broad dev/test public access; production should use private networking.
- No Application Insights/OpenTelemetry tracing yet.
- No automated integration tests or Container Apps post-deploy smoke test job yet.
