# CI/CD theo hướng thực tế

Repo này tách CI, CD ứng dụng và provision hạ tầng thành các workflow riêng.

## CI

File:

```text
.github/workflows/ci.yml
```

Khi push hoặc mở pull request, workflow chạy:

```text
mvn test
```

CI chỉ kiểm tra code. CI không deploy.

## CD ứng dụng

File:

```text
.github/workflows/deploy-azure-container-apps.yml
```

CD chỉ chạy sau khi workflow `CI` trên branch `main` hoặc `master` thành công.

CD không tạo hạ tầng Azure mỗi lần chạy. Nó chỉ:

```text
1. Login Azure
2. Sinh infra/azure/env.ps1 từ GitHub variables/secrets
3. Build Docker image cho service cần deploy
4. Push image lên Azure Container Registry
5. Update Azure Container App tương ứng
```

CD không chạy smoke test sau deploy. Kiểm thử sau deploy nên là một workflow hoặc job riêng cho integration/e2e test, không trộn vào deploy app mặc định.

## Deploy theo service

Nếu thay đổi file trong:

```text
services/product-service/**
```

thì chỉ build/deploy:

```text
product-service
```

Nếu thay đổi:

```text
services/order-service/**
```

thì chỉ build/deploy:

```text
order-service
```

Nếu thay đổi `pom.xml`, workflow deploy toàn bộ service vì đây là cấu hình build dùng chung.

Khi chạy tay trong GitHub Actions, có thể chọn:

```text
auto
all
user-service
product-service
notification-service
order-service
gateway-service
```

## Image tag

Mặc định image tag là commit SHA, không dùng `latest`.

Ví dụ:

```text
mscloudacrdeve9a4b0.azurecr.io/product-service:<commit-sha>
```

Khi chạy tay có thể nhập `image_tag`, nhưng bình thường nên để trống để dùng commit SHA.

## Hạ tầng Azure

File:

```text
.github/workflows/provision-azure-infra.yml
```

Workflow này chạy tay khi cần tạo hoặc cập nhật hạ tầng:

```text
Resource Group
Azure Container Registry
Container Apps Environment
Managed Identity
Azure PostgreSQL Flexible Server
Database theo service
```

Trong thực tế, bước hạ tầng không nên chạy chung với mỗi lần deploy code ứng dụng.

## Secrets và variables

Secrets cần có:

```text
AZURE_CREDENTIALS
AZURE_POSTGRES_ADMIN_PASSWORD
```

Variables cần có:

```text
PROJECT_NAME
ENVIRONMENT_NAME
AZURE_LOCATION
AZURE_RESOURCE_GROUP
AZURE_CONTAINER_APPS_ENV
AZURE_LOG_ANALYTICS_WORKSPACE
AZURE_USER_ASSIGNED_IDENTITY
AZURE_CONTAINER_REGISTRY
AZURE_POSTGRES_SERVER
AZURE_POSTGRES_ADMIN_USER
AZURE_POSTGRES_SKU
AZURE_POSTGRES_TIER
AZURE_POSTGRES_VERSION
```
