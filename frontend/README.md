# MSCloud Frontend

Đây là một Single-Page Application (SPA) viết bằng HTML/CSS/JS thuần, đóng vai trò là giao diện người dùng cho hệ thống **MSCloud Microservices**.

## 🌟 Tính năng
- Giao diện Landing Page hiện đại.
- **Xác thực người dùng:** Đăng ký và Đăng nhập bảo mật bằng **Microsoft Entra External ID** thông qua thư viện `MSAL.js`.
- **Gọi API có bảo mật:** Tự động đính kèm `JWT Access Token` vào header khi gọi API.
- **Tương tác Microservices:** Xem danh sách sản phẩm, đặt hàng, gửi thông báo.

## 🚀 Cách chạy ở máy cá nhân (Local)

1. Cài đặt Node.js (nếu chưa có).
2. Mở terminal tại thư mục `frontend` này.
3. Khởi động server tĩnh bằng lệnh:
   ```bash
   npx http-server -p 3000
   ```
4. Mở trình duyệt tại địa chỉ: `http://localhost:3000`

> **Lưu ý:** Để chức năng Đăng nhập hoạt động trên Localhost, bạn phải khai báo `http://localhost:3000` vào danh sách **Redirect URIs** của App Registration (mục Single-page application) trên Azure Portal.

## ☁️ Triển khai lên Azure Static Web Apps

Frontend này đã được tích hợp luồng CI/CD với GitHub Actions (`deploy-frontend.yml`).

Mỗi khi bạn `push` code mới vào nhánh `main`, GitHub Actions sẽ tự động đẩy code lên **Azure Static Web Apps**. 

**Cách cài đặt CI/CD lần đầu:**
1. Tạo Azure Static Web App qua Azure CLI:
   ```bash
   az staticwebapp create --name "mscloud-frontend" --resource-group "rg-mscloud-dev" --location "eastasia" --sku "Free"
   ```
2. Lấy API Token:
   ```bash
   az staticwebapp secrets list --name "mscloud-frontend" --query "properties.apiKey" --output tsv
   ```
3. Lưu API Token này vào GitHub Secrets với tên `AZURE_STATIC_WEB_APPS_API_TOKEN`.

> **Lưu ý:** Sau khi triển khai lên Azure và có tên miền thật (VD: `https://white-wave-xxx.azurestaticapps.net`), bạn cần đưa URL này vào danh sách **Redirect URIs** trên Azure Portal.

## 🔐 Cấu hình Microsoft Entra External ID
File `index.html` chứa cấu hình kết nối ở ngay đầu đoạn script. Hãy điều chỉnh thông số ở `MSAL_CONFIG` nếu bạn thay đổi Tenant trên Azure.

```javascript
const MSAL_CONFIG = {
  auth: {
    clientId: "60a64e05-36c6-4622-bb59-a7d84d9ad6f6",
    authority: "https://mscloudauth.ciamlogin.com/18d1a24d-3c27-4747-813e-f90bba6911cf/",
    redirectUri: window.location.origin + window.location.pathname,
    postLogoutRedirectUri: window.location.origin + window.location.pathname,
    knownAuthorities: ["mscloudauth.ciamlogin.com"],
  }
};
```
