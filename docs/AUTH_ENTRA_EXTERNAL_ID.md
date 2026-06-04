# Auth bằng Microsoft Entra External ID

Gateway đã hỗ trợ JWT/OIDC nhưng mặc định đang tắt để demo cũ vẫn chạy.

## Cách bật trên Azure

Sau khi tạo Entra External ID tenant và app/API registration, set GitHub repository variables:

```text
AUTH_ENABLED=true
AUTH_ISSUER_URI=https://<tenant-name>.ciamlogin.com/<tenant-id>/v2.0
AUTH_AUDIENCE=<api-client-id-hoặc-app-id-uri>
```

Sau đó chạy GitHub Actions:

```text
Deploy Azure Container Apps
deploy_mode = build-and-deploy
service = gateway-service
image_tag = để trống
```

Nếu chỉ đổi `AUTH_*` variables mà không đổi code, chạy:

```text
deploy_mode = config-only
service = gateway-service
```

## Hành vi hiện tại

- Public:
  - `GET /api/health`
  - `GET /api/products`
  - `GET /api/products/{id}`
- Cần JWT khi `AUTH_ENABLED=true`:
  - `GET /api/me`
  - `POST /api/orders`
  - `GET /api/orders/my`
  - `POST /api/notifications/test`

Gateway lấy user từ JWT:

```text
X-User-Id = sub
X-User-Email = email hoặc preferred_username
```

Service con vẫn nhận identity qua header nội bộ từ gateway.
