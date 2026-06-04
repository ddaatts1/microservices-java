# Hướng Dẫn Bật Auth Bằng Microsoft Entra External ID

Gateway đã hỗ trợ JWT/OIDC. Mặc định auth đang tắt để demo cũ vẫn chạy:

```text
AUTH_ENABLED=false
```

Khi bật auth thật:

- `gateway-service` kiểm tra Bearer JWT.
- Gateway lấy `sub` và `email/preferred_username` từ token.
- Gateway tự gắn header nội bộ:
  - `X-User-Id`
  - `X-User-Email`
- Service con không cần tự xử lý đăng nhập.

## 1. Tạo External ID Tenant Trên Azure Portal

Vào:

```text
https://entra.microsoft.com
```

Làm theo các bước:

1. Bấm biểu tượng bánh răng hoặc tenant ở góc phải trên.
2. Chọn **Switch tenant** hoặc **Manage tenants**.
3. Bấm **Create**.
4. Chọn **External** hoặc **External ID tenant**.
5. Điền tên tenant, ví dụ:

```text
mscloud-customers
```

6. Chọn region phù hợp.
7. Bấm **Review + create**.
8. Sau khi tạo xong, switch sang tenant External ID vừa tạo.

## 2. Tạo App Registration Cho Backend API

Trong External ID tenant:

```text
Microsoft Entra ID > App registrations > New registration
```

Điền:

```text
Name: mscloud-api
Supported account types: Accounts in this organizational directory only
Redirect URI: bỏ trống
```

Bấm **Register**.

Sau khi tạo xong, copy lại:

```text
Application (client) ID
Directory (tenant) ID
```

## 3. Expose API

Trong app `mscloud-api`:

```text
Expose an API
```

Nếu thấy nút **Set** ở phần **Application ID URI**, bấm **Set**.

Có thể để mặc định dạng:

```text
api://<APPLICATION_CLIENT_ID>
```

Sau đó bấm:

```text
Add a scope
```

Điền ví dụ:

```text
Scope name: access_as_user
Who can consent: Admins and users
Admin consent display name: Access mscloud API
Admin consent description: Allow the app to access mscloud API.
User consent display name: Access mscloud API
User consent description: Allow the app to access mscloud API.
State: Enabled
```

Lưu lại scope.

Giá trị cần nhớ:

```text
AUTH_AUDIENCE = Application (client) ID
```

Hoặc nếu bạn muốn dùng Application ID URI:

```text
AUTH_AUDIENCE = api://<APPLICATION_CLIENT_ID>
```

Với code hiện tại, khuyến nghị dùng:

```text
AUTH_AUDIENCE = <APPLICATION_CLIENT_ID>
```

Quan trọng: giá trị `AUTH_AUDIENCE` phải khớp chính xác claim `aud` trong access token. Nếu token của bạn có `aud` là `api://<APPLICATION_CLIENT_ID>` thì set đúng dạng đó. Nếu token có `aud` là `<APPLICATION_CLIENT_ID>` thì set client id.

Cách kiểm tra:

```text
1. Lấy access token từ app/client.
2. Mở https://jwt.ms
3. Dán token vào.
4. Xem claim aud.
5. Set AUTH_AUDIENCE bằng đúng giá trị aud đó.
```

## 4. Lấy Issuer URI

Issuer URI thường có dạng:

```text
https://<tenant-name>.ciamlogin.com/<tenant-id>/v2.0
```

Ví dụ:

```text
https://mscloud-customers.ciamlogin.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/v2.0
```

Trong đó:

- `<tenant-name>` là tên External ID tenant.
- `<tenant-id>` là **Directory (tenant) ID**.

Biến cần set:

```text
AUTH_ISSUER_URI=https://<tenant-name>.ciamlogin.com/<tenant-id>/v2.0
```

## 5. Set GitHub Repository Variables

Chạy trên máy đã login GitHub CLI:

```powershell
gh auth login
```

Set variables:

```powershell
gh variable set AUTH_ENABLED --body "true" --repo ddaatts1/microservices-java

gh variable set AUTH_ISSUER_URI --body "https://<tenant-name>.ciamlogin.com/<tenant-id>/v2.0" --repo ddaatts1/microservices-java

gh variable set AUTH_AUDIENCE --body "<application-client-id>" --repo ddaatts1/microservices-java
```

Kiểm tra lại:

```powershell
gh variable list --repo ddaatts1/microservices-java
```

## 6. Deploy Lại Gateway

Vào GitHub:

```text
Repo > Actions > Deploy Azure Container Apps > Run workflow
```

Chọn:

```text
deploy_mode = build-and-deploy
service = gateway-service
image_tag = để trống
```

Bấm **Run workflow**.

Nếu chỉ đổi `AUTH_*` variables mà không đổi code, có thể chạy nhanh:

```text
deploy_mode = config-only
service = gateway-service
image_tag = để trống
```

## 7. Test Sau Khi Bật Auth

Public API vẫn gọi được:

```powershell
Invoke-RestMethod "https://gateway-service.graybay-d4e6295a.southeastasia.azurecontainerapps.io/api/health"

Invoke-RestMethod "https://gateway-service.graybay-d4e6295a.southeastasia.azurecontainerapps.io/api/products"
```

API cần login sẽ trả `401 Unauthorized` nếu không có token:

```powershell
Invoke-RestMethod "https://gateway-service.graybay-d4e6295a.southeastasia.azurecontainerapps.io/api/me"
```

Khi đã có access token:

```powershell
$token = "<access-token>"

Invoke-RestMethod `
  -Uri "https://gateway-service.graybay-d4e6295a.southeastasia.azurecontainerapps.io/api/me" `
  -Headers @{ Authorization = "Bearer $token" }
```

Nếu vẫn bị `401 Unauthorized`, kiểm tra theo thứ tự:

```text
1. Token có phải access token không, không dùng id token.
2. Claim iss trong token có đúng AUTH_ISSUER_URI không.
3. Claim aud trong token có đúng AUTH_AUDIENCE không.
4. Token còn hạn không, kiểm tra exp.
5. Workflow Deploy Azure Container Apps đã chạy lại gateway chưa.
```

Trong Azure Portal, kiểm tra gateway đã nhận config chưa:

```text
Container Apps > gateway-service > Settings > Environment variables
```

Phải thấy:

```text
AUTH_ENABLED=true
AUTH_ISSUER_URI=<issuer-uri>
AUTH_AUDIENCE=<audience>
```

## 8. Các Route Hiện Tại

Public:

```text
GET /api/health
GET /api/products
GET /api/products/{id}
```

Cần JWT khi `AUTH_ENABLED=true`:

```text
GET /api/me
POST /api/orders
GET /api/orders/my
POST /api/notifications/test
```

## 9. Ghi Chú Quan Trọng

- Đổi variables trên GitHub chưa tự làm Azure đổi ngay.
- Sau khi đổi `AUTH_*`, phải chạy workflow deploy lại gateway.
- Nếu chỉ đổi config, dùng `deploy_mode=config-only`.
- Nếu đổi code gateway, dùng `deploy_mode=build-and-deploy`.
- Không tự gửi `X-User-Id` từ client nữa khi auth thật đã bật. Gateway sẽ tự sinh header này từ JWT.
