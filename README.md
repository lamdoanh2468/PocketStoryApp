# PocketStoryApp

PocketStoryApp là ứng dụng quản lý tài chính cá nhân thông minh được xây dựng bằng Flutter, Firebase và Node.js. Ứng dụng giúp người dùng ghi lại thu nhập, khoản chi, ngân sách, xem báo cáo trực quan và hỏi chatbot AI để phân tích thói quen chi tiêu.

Backend chatbot có thể chạy trên Ubuntu Server bằng Docker Compose và được public qua Cloudflare Tunnel tại domain dạng:

```txt
https://chat.pocketstoryapp.io.vn
```

---

## Mục lục

- [1. Tổng quan hệ thống](#1-tổng-quan-hệ-thống)
- [2. Công nghệ sử dụng](#2-công-nghệ-sử-dụng)
- [3. Chức năng chính](#3-chức-năng-chính)
- [4. Cấu trúc thư mục](#4-cấu-trúc-thư-mục)
- [5. Cài đặt môi trường](#5-cài-đặt-môi-trường)
- [6. Chạy Flutter app](#6-chạy-flutter-app)
- [7. Chạy chatbot backend local](#7-chạy-chatbot-backend-local)
- [8. Deploy backend bằng Ubuntu Server, Docker và Cloudflare Tunnel](#8-deploy-backend-bằng-ubuntu-server-docker-và-cloudflare-tunnel)
- [9. Flow hoạt động](#9-flow-hoạt-động)
- [10. Test API](#10-test-api)
- [11. Build APK](#11-build-apk)
- [12. Lỗi thường gặp](#12-lỗi-thường-gặp)
- [13. Bảo mật](#13-bảo-mật)

---

## 1. Tổng quan hệ thống

PocketStoryApp gồm 2 phần chính:

```txt
Flutter mobile app
  ├─ Firebase Authentication
  ├─ Cloud Firestore
  ├─ Firebase Storage
  ├─ Firebase Messaging
  └─ Gọi PocketStory API để dùng chatbot AI

PocketStory API - Node.js backend
  ├─ Verify Firebase ID token
  ├─ Đọc dữ liệu entries và budgets trong Firestore
  ├─ Tóm tắt dữ liệu tài chính
  ├─ Gọi Gemini API
  └─ Trả kết quả phân tích về Flutter app
```

Luồng triển khai backend:

```txt
Internet / Flutter app
  → https://chat.pocketstoryapp.io.vn
  → Cloudflare Tunnel
  → cloudflared container trên Ubuntu Server
  → pocketstory-api container
  → Firebase Admin SDK + Gemini API
```

---

## 2. Công nghệ sử dụng

### Mobile app

- Flutter.
- Dart SDK `>=3.4.0 <4.0.0`.
- Firebase Core.
- Firebase Authentication.
- Cloud Firestore.
- Firebase Storage.
- Firebase Messaging.
- Google Sign-In.
- Provider.
- HTTP.
- Image Picker.
- FL Chart.
- Intl.
- Shared Preferences.

### Backend chatbot

Backend nằm trong thư mục:

```txt
pocketstory-api/
```

Công nghệ chính:

- Node.js `>=20`.
- Express.
- Firebase Admin SDK.
- Gemini API.
- CORS.
- Helmet.
- Morgan.
- Dotenv.

### Deploy

- Ubuntu Server.
- Docker.
- Docker Compose.
- Cloudflare Tunnel.
- Domain HTTPS qua Cloudflare.

---

## 3. Chức năng chính

### 3.1. Đăng ký và đăng nhập

Ứng dụng sử dụng Firebase Authentication để xác thực người dùng.

Hỗ trợ:

- Đăng ký bằng email/password.
- Đăng nhập bằng email/password.
- Đăng nhập Google.
- Đăng xuất.
- Lấy Firebase ID token để gọi backend chatbot.

Mỗi user có dữ liệu riêng theo `uid` trong Firestore.

### 3.2. Quản lý thu nhập và chi tiêu

Người dùng có thể tạo giao dịch tài chính cá nhân với các thông tin:

- Loại giao dịch: `income` hoặc `expense`.
- Số tiền.
- Danh mục.
- Ghi chú.
- Hình ảnh liên quan.
- Ngày phát sinh.

Dữ liệu được lưu tại:

```txt
users/{uid}/entries/{entryId}
```

### 3.3. Quản lý ngân sách

Người dùng có thể tạo và chỉnh sửa ngân sách theo danh mục.

Chức năng ngân sách gồm:

- Tạo ngân sách theo tháng.
- Chỉnh sửa ngân sách đã tạo.
- Xóa ngân sách.
- Tự động format hạn mức theo VND khi nhập, ví dụ:

```txt
1000000 → 1.000.000 VND
```

- Hiển thị tiến độ đã dùng ngân sách bằng thanh progress.
- Cảnh báo khi sắp chạm hoặc vượt ngân sách.

Dữ liệu được lưu tại:

```txt
users/{uid}/budgets/{budgetId}
```

### 3.4. Báo cáo và biểu đồ

Ứng dụng tổng hợp dữ liệu thu/chi để hiển thị báo cáo:

- Tổng thu.
- Tổng chi.
- Số dư.
- Chi tiêu theo danh mục.
- Chi tiêu theo thời gian.
- So sánh xu hướng giữa các khoảng thời gian.
- Biểu đồ trực quan bằng `fl_chart`.

### 3.5. Cảnh báo

Ứng dụng có collection cảnh báo:

```txt
users/{uid}/alerts/{alertId}
```

Dùng để lưu các cảnh báo liên quan đến ngân sách hoặc tình hình chi tiêu.

### 3.6. Chatbot AI phân tích chi tiêu

Chatbot AI phân tích dữ liệu tài chính của user hiện tại.

Endpoint chính:

```txt
POST /api/chatbot/analyze
```

Backend sẽ:

- Nhận Firebase ID token từ Flutter app.
- Verify token bằng Firebase Admin SDK.
- Lấy `uid` từ token.
- Đọc `entries` và `budgets` của user trong Firestore.
- Tóm tắt dữ liệu thu/chi.
- Gửi prompt đến Gemini API.
- Trả câu trả lời phân tích về app.

Nếu Gemini lỗi hoặc chưa cấu hình API key, backend có thể trả kết quả phân tích cục bộ ở mức cơ bản.

### 3.7. Chuyển giao diện sáng/tối

Ứng dụng có nút chuyển giao diện sáng/tối trên AppBar chính.

- Giao diện sáng dùng `AppTheme.lightTheme`.
- Giao diện tối dùng `AppTheme.darkTheme`.
- Lựa chọn theme được lưu bằng `shared_preferences`.
- Khi mở lại app, theme đã chọn trước đó sẽ được giữ lại.

---

## 4. Cấu trúc thư mục

```txt
PocketStoryApp/
├── lib/
│   ├── constants/                 # Danh mục, hằng số
│   ├── models/                    # Model dữ liệu: Budget, MoneyEntry, Alert...
│   ├── screens/                   # Các màn hình Flutter
│   │   ├── auth/                  # Đăng nhập / đăng ký
│   │   ├── budget/                # Quản lý ngân sách
│   │   ├── chatbot/               # Chatbot AI
│   │   ├── dashboard/             # Tổng quan
│   │   ├── diary/                 # Nhật ký giao dịch
│   │   ├── entry/                 # Thêm khoản thu/chi
│   │   └── report/                # Báo cáo / biểu đồ
│   ├── services/                  # AuthService, FinanceRepository, ChatbotService...
│   ├── theme/                     # Theme sáng/tối
│   └── utils/                     # Format tiền, xử lý ngày...
│
├── pocketstory-api/
│   ├── src/
│   │   └── index.js               # Express API chatbot
│   ├── Dockerfile
│   ├── package.json
│   └── .env.example
│
├── docs/
│   └── firestore_schema.md
│
├── docker-compose.yml
├── pubspec.yaml
├── firebase.json
├── firestore.rules
├── storage.rules
└── README.md
```

---

## 5. Cài đặt môi trường

### 5.1. Công cụ cần có

Cài các công cụ sau trên máy phát triển:

- Git.
- Flutter SDK.
- Android Studio hoặc VS Code.
- Firebase CLI nếu cần deploy rules/functions.
- Node.js `>=20` nếu chạy backend local.
- Docker và Docker Compose nếu deploy backend bằng container.

Kiểm tra Flutter:

```bash
flutter doctor
```

Kiểm tra Node.js:

```bash
node -v
npm -v
```

Kiểm tra Docker:

```bash
docker --version
docker compose version
```

### 5.2. Clone repo

```bash
git clone https://github.com/lamdoanh2468/PocketStoryApp.git
cd PocketStoryApp
```

### 5.3. Cài dependencies Flutter

```bash
flutter pub get
```

---

## 6. Chạy Flutter app

Chạy app ở môi trường local:

```bash
flutter run
```

Mặc định app có thể gọi backend chatbot theo URL đã cấu hình trong code. Nếu muốn ép app gọi domain production, chạy:

```bash
flutter run --dart-define=POCKETSTORY_API_BASE_URL=https://chat.pocketstoryapp.io.vn
```

Khi build release cũng nên truyền URL backend:

```bash
flutter build apk --release --dart-define=POCKETSTORY_API_BASE_URL=https://chat.pocketstoryapp.io.vn
```

---

## 7. Chạy chatbot backend local

Vào thư mục API:

```bash
cd pocketstory-api
```

Tạo file `.env`:

```bash
cp .env.example .env
```

Ví dụ `.env` local:

```env
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*

FIREBASE_PROJECT_ID=pocketstory-6d696
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json

GEMINI_API_KEY=PASTE_GEMINI_API_KEY_HERE
GEMINI_MODEL=gemini-1.5-flash
```

Cài package Node.js:

```bash
npm install
```

Chạy API:

```bash
npm run dev
```

Test API:

```bash
curl http://localhost:3000/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

---

## 8. Deploy backend bằng Ubuntu Server, Docker và Cloudflare Tunnel

### 8.1. Luồng deploy tổng quát

```txt
Ubuntu Server
  → cài Docker và Docker Compose
  → clone repo PocketStoryApp
  → tạo file .env ở root repo
  → tạo file pocketstory-api/.env
  → copy Firebase Admin SDK JSON vào server
  → tạo Cloudflare Tunnel
  → add route chat.pocketstoryapp.io.vn → http://pocketstory-api:3000
  → chạy docker compose up -d --build
```

### 8.2. Cài Docker trên Ubuntu

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

### 8.3. Clone repo trên server

```bash
git clone https://github.com/lamdoanh2468/PocketStoryApp.git
cd PocketStoryApp
```

### 8.4. Tạo file `.env` ở root project

File này dùng cho Docker Compose và Cloudflare Tunnel.

```bash
nano .env
```

Nội dung mẫu:

```env
APP_PORT=3000
CLOUDFLARE_TUNNEL_TOKEN=PASTE_CLOUDFLARE_TUNNEL_TOKEN_HERE
```

### 8.5. Tạo file `.env` cho backend API

```bash
nano pocketstory-api/.env
```

Nội dung mẫu:

```env
PORT=3000
NODE_ENV=production
CORS_ORIGIN=*

FIREBASE_PROJECT_ID=pocketstory-6d696
GOOGLE_APPLICATION_CREDENTIALS=/app/firebase-service-account.json

GEMINI_API_KEY=PASTE_GEMINI_API_KEY_HERE
GEMINI_MODEL=gemini-1.5-flash
```

### 8.6. Copy Firebase Admin SDK JSON vào server

Ví dụ đặt file tại:

```txt
~/PocketStoryApp/pocketstory-api/firebase-service-account.json
```

Copy từ máy local sang Ubuntu:

```bash
scp ./pocketstory-api/firebase-service-account.json username@SERVER_IP:~/PocketStoryApp/pocketstory-api/
```

Kiểm tra:

```bash
ls -la pocketstory-api/*.json
```

### 8.7. Cấu hình Cloudflare Tunnel

Trong Cloudflare Zero Trust, tạo tunnel và thêm Public Hostname:

```txt
Subdomain: chat
Domain: pocketstoryapp.io.vn
Service: http://pocketstory-api:3000
```

Kết quả:

```txt
https://chat.pocketstoryapp.io.vn → http://pocketstory-api:3000
```

`pocketstory-api` là tên service/container trong Docker Compose. Vì `cloudflared` và `pocketstory-api` chạy chung Docker network, Cloudflare Tunnel có thể gọi API qua service name này.

### 8.8. Docker Compose khuyến nghị

Vì Node.js backend nằm trong thư mục `pocketstory-api/`, Docker Compose nên build từ context này:

```yaml
services:
  pocketstory-api:
    build:
      context: ./pocketstory-api
      dockerfile: Dockerfile
    container_name: pocketstory-api
    restart: unless-stopped
    env_file:
      - ./pocketstory-api/.env
    environment:
      NODE_ENV: production
      PORT: 3000
      GOOGLE_APPLICATION_CREDENTIALS: /app/firebase-service-account.json
    volumes:
      - ./pocketstory-api/firebase-service-account.json:/app/firebase-service-account.json:ro
    ports:
      - "${APP_PORT:-3000}:3000"

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: pocketstory-cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    depends_on:
      - pocketstory-api
```

Nếu file service account của bạn có tên khác, sửa lại đường dẫn ở phần `volumes`.

### 8.9. Chạy container

```bash
cd ~/PocketStoryApp
sudo docker compose down
sudo docker compose up -d --build
```

Kiểm tra:

```bash
sudo docker ps
```

Cần thấy 2 container:

```txt
pocketstory-api
pocketstory-cloudflared
```

Xem log API:

```bash
sudo docker logs -f pocketstory-api
```

Xem log tunnel:

```bash
sudo docker logs -f pocketstory-cloudflared
```

---

## 9. Flow hoạt động

### 9.1. Flow đăng nhập

```txt
User mở app
  → đăng nhập email/password hoặc Google
  → Firebase Authentication xác thực
  → app lấy user hiện tại
  → app tạo/cập nhật profile trong Firestore
```

### 9.2. Flow ghi nhận thu/chi

```txt
User nhập khoản thu/chi
  → chọn loại income/expense
  → nhập số tiền, danh mục, ghi chú, hình ảnh, ngày phát sinh
  → app lưu vào users/{uid}/entries
  → dashboard, nhật ký và báo cáo cập nhật theo dữ liệu mới
```

### 9.3. Flow ngân sách

```txt
User tạo ngân sách
  → chọn danh mục
  → nhập hạn mức theo VND
  → app lưu vào users/{uid}/budgets
  → app so sánh chi tiêu thực tế với hạn mức
  → hiển thị progress và cảnh báo nếu sắp vượt/vượt ngân sách
```

Khi chỉnh sửa ngân sách:

```txt
User bấm icon edit ở budget
  → dữ liệu được đưa lên form
  → user sửa hạn mức hoặc danh mục
  → app cập nhật lại budget trong Firestore
```

### 9.4. Flow chatbot AI

```txt
User hỏi chatbot
  → Flutter lấy Firebase ID token
  → Flutter gửi POST /api/chatbot/analyze
  → Backend verify token bằng Firebase Admin SDK
  → Backend lấy uid từ token
  → Backend đọc users/{uid}/entries và users/{uid}/budgets
  → Backend tóm tắt dữ liệu
  → Backend gọi Gemini API
  → Backend trả kết quả về Flutter
  → App hiển thị câu trả lời
```

### 9.5. Flow Cloudflare Tunnel

```txt
Flutter app gọi https://chat.pocketstoryapp.io.vn
  → Cloudflare nhận request
  → Cloudflare Tunnel chuyển về cloudflared container
  → cloudflared gọi http://pocketstory-api:3000
  → Express API xử lý request
  → response trả ngược về Flutter app
```

---

## 10. Test API

### 10.1. Test local trên Ubuntu Server

```bash
curl http://localhost:3000/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

### 10.2. Test qua domain Cloudflare

```bash
curl https://chat.pocketstoryapp.io.vn/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

### 10.3. Test chatbot không có token

```bash
curl -X POST https://chat.pocketstoryapp.io.vn/api/chatbot/analyze \
  -H "Content-Type: application/json" \
  -d '{"question":"Phân tích chi tiêu của tôi trong 30 ngày gần đây","rangeDays":30}'
```

Kết quả sau là bình thường vì endpoint chatbot yêu cầu Firebase ID token:

```json
{"message":"Missing Firebase ID token."}
```

### 10.4. Test chatbot có token

```bash
curl -X POST https://chat.pocketstoryapp.io.vn/api/chatbot/analyze \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer FIREBASE_ID_TOKEN_CUA_USER" \
  -d '{"question":"Phân tích chi tiêu của tôi trong 30 ngày gần đây","rangeDays":30}'
```

---

## 11. Build APK

Build APK release:

```bash
flutter build apk --release --dart-define=POCKETSTORY_API_BASE_URL=https://chat.pocketstoryapp.io.vn
```

File APK thường nằm ở:

```txt
build/app/outputs/flutter-apk/app-release.apk
```

---

## 12. Lỗi thường gặp

### 12.1. Thiếu file `.env`

Lỗi:

```txt
env file ... not found
```

Cách xử lý:

```bash
nano .env
nano pocketstory-api/.env
```

Đảm bảo có đủ biến môi trường cho Docker Compose, Cloudflare Tunnel, Firebase và Gemini.

### 12.2. Docker không pull được image do DNS

Lỗi:

```txt
lookup registry-1.docker.io ... i/o timeout
```

Có thể cấu hình DNS cho Docker:

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

Nội dung:

```json
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### 12.3. Backend thiếu Firebase credential

Lỗi thường gặp:

```txt
Failed to read credentials from file
```

Cách xử lý:

- Kiểm tra file Firebase Admin SDK JSON có tồn tại trên Ubuntu server chưa.
- Kiểm tra `GOOGLE_APPLICATION_CREDENTIALS`.
- Kiểm tra phần `volumes` trong `docker-compose.yml`.

### 12.4. Chatbot báo `Missing Firebase ID token`

Điều này bình thường nếu gọi API bằng `curl` mà chưa truyền token.

Cần thêm header:

```txt
Authorization: Bearer FIREBASE_ID_TOKEN_CUA_USER
```

Flutter app sẽ tự lấy token từ user đã đăng nhập và gửi lên backend.

### 12.5. Cloudflare Tunnel Healthy nhưng domain không chạy

Kiểm tra:

- Public Hostname có đúng `chat.pocketstoryapp.io.vn` không.
- Service có đúng `http://pocketstory-api:3000` không.
- Container `pocketstory-api` có đang chạy không.
- Container `pocketstory-cloudflared` có đang chạy không.
- `curl http://localhost:3000/health` trên Ubuntu có OK không.

---

## 13. Bảo mật

Không commit các file hoặc giá trị sau lên GitHub:

- `.env`.
- Firebase Admin SDK JSON.
- Gemini API key.
- Cloudflare Tunnel token.
- Private key hoặc credential cá nhân.

Nếu lỡ public secret, cần rotate hoặc revoke secret ngay.

---

## Tóm tắt nhanh

```txt
1. User đăng nhập Firebase trong Flutter app.
2. User nhập thu/chi và ngân sách.
3. Dữ liệu lưu trong Firestore theo users/{uid}.
4. User hỏi chatbot.
5. Flutter lấy Firebase ID token.
6. Flutter gọi https://chat.pocketstoryapp.io.vn/api/chatbot/analyze.
7. Cloudflare Tunnel chuyển request về Ubuntu Server.
8. Node.js backend verify token và đọc Firestore.
9. Backend gọi Gemini API.
10. Flutter hiển thị câu trả lời.
```
