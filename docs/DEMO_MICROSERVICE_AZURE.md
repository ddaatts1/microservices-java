# Demo microservice deploy lên Azure

Mục tiêu demo: dùng `product-service` để minh họa đầy đủ đường đi của một microservice Java từ source code lên Azure.

PowerPoint thuyết trình tương ứng nằm ở:

```text
C:\Users\Admin\Desktop\ms cloud\mscloud\TLTT_Nhom1_Microservice_Azure_Demo.pptx
```

## Service dùng để demo

`product-service` là service phù hợp để trình bày vì có đủ các phần cần thiết nhưng không quá phức tạp:

- Spring Boot API chạy bằng Java 17.
- Maven build ra JAR.
- Dockerfile đóng gói thành container image.
- PostgreSQL database `product_db`.
- Flyway migration tạo schema.
- Cấu hình production bằng environment variables.
- Endpoint kiểm tra: `/api/products`, `/api/products/{id}`, `/actuator/health`.

## Các thành phần cần dùng

| Thành phần | Mục đích |
|---|---|
| Maven | Build source code Java thành JAR. |
| Dockerfile | Đóng gói JAR và Java runtime thành image. |
| Azure Container Registry | Lưu Docker image trên Azure để Container Apps kéo về chạy. |
| Azure Container Apps | Chạy container, expose API, cấu hình replica/ingress/env vars. |
| Azure Database for PostgreSQL | Lưu dữ liệu thật thay cho PostgreSQL local trong Docker Compose. |
| Secrets/env vars | Tách password, connection string, port và profile ra khỏi source code. |
| GitHub Actions | Tự động hóa build, push image và deploy khi cần. |

## Thứ tự demo đề xuất

1. Mở `services/product-service`.
2. Chỉ ra `pom.xml`, `Dockerfile`, `application-prod.yml`, Flyway migration.
3. Chạy kiểm tra local:

```powershell
mvn test
docker compose config
```

4. Tạo config Azure dev/test nếu chưa có:

```powershell
.\infra\azure\init-env.ps1
```

5. Chạy preflight:

```powershell
.\infra\azure\test-preflight.ps1
```

6. Khi preflight pass, deploy demo 1 service:

```powershell
.\infra\azure\create-infra.ps1
.\infra\azure\build-push-product-service.ps1
.\infra\azure\deploy-product-service-demo.ps1
.\infra\azure\test-product-service-demo.ps1
```

Hoặc chạy gộp:

```powershell
.\infra\azure\deploy-demo-product-service.ps1
```

Nếu muốn deploy toàn bộ 5 service sau phần demo, dùng `deploy-all.ps1`.

## Kiểm tra sau deploy

Sau khi deploy xong, script sẽ in ra Product Service demo URL. Dùng URL đó để kiểm tra:

```powershell
Invoke-RestMethod https://<product-service-demo-fqdn>/actuator/health
Invoke-RestMethod https://<product-service-demo-fqdn>/api/products
```

## Blocker hiện tại trên máy này

`test-preflight.ps1` hiện giúp phát hiện sớm các lỗi trước khi tạo resource Azure. Trạng thái hiện tại trên máy này còn:

- Docker Desktop chưa chạy.
- Azure CLI login/subscription chưa truy vấn được resource group.

Sau khi hai lỗi này được xử lý, preflight sẽ kiểm tra tiếp tên ACR và PostgreSQL Flexible Server có globally unique hay không.

## Điểm cần nói khi thuyết trình

Deploy một microservice không chỉ là upload code. Ta cần biến app thành image, lưu image, tạo môi trường chạy container, cấu hình database/secrets, rồi kiểm chứng API. Azure Container Apps giúp giảm phần vận hành hạ tầng container, còn GitHub Actions giúp quy trình deploy lặp lại tự động.
