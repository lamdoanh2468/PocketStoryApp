# PocketStoryApp

PocketStory là ứng dụng nhật ký tài chính cá nhân thông minh được xây dựng bằng Flutter và Firebase. Ứng dụng giúp người dùng ghi nhận thu nhập, chi tiêu, ngân sách, xem thống kê tài chính cá nhân và sử dụng chatbot AI để phân tích thói quen chi tiêu.

Repo này gồm 2 phần chính:

- Ứng dụng Flutter ở thư mục gốc, dùng cho mobile app.
- Backend Node.js ở thư mục `pocketstory-api/`, dùng cho chatbot phân tích chi tiêu bằng AI.

---

## 1. Chức năng chính

### 1.1. Xác thực người dùng

- Đăng ký và đăng nhập bằng Firebase Authentication.
- Hỗ trợ đăng nhập bằng email/password.
- Hỗ trợ đăng nhập Google.
- Mỗi người dùng có dữ liệu tài chính riêng theo `uid` trong Firestore.

### 1.2. Quản lý thu nhập và chi tiêu

Người dùng có thể ghi nhận các giao dịch tài chính cá nhân, bao gồm:

- Loại giao dịch: `income` hoặc `expense`.
- Số tiền.
- Danh mục.
- Ghi chú.
- Hình ảnh liên quan đến khoản chi.
- Thời gian phát sinh giao dịch.

Dữ liệu được lưu theo cấu trúc:

```txt
users/{uid}/entries/{entryId}
```

### 1.3. Quản lý ngân sách

Người dùng có thể tạo ngân sách theo danh mục và khoảng thời gian:

- Danh mục ngân sách.
- Số tiền giới hạn.
- Ngày bắt đầu.
- Ngày kết thúc.

Dữ liệu được lưu theo cấu trúc:

```txt
users/{uid}/budgets/{budgetId}
```

### 1.4. Thống kê, biểu đồ và báo cáo

Ứng dụng hỗ trợ tổng hợp dữ liệu thu/chi để người dùng theo dõi tình hình tài chính cá nhân:

- Tổng thu.
- Tổng chi.
- Số dư.
- Danh mục chi nhiều nhất.
- Ngày có mức chi cao.
- So sánh chi tiêu theo khoảng thời gian.
- Hiển thị biểu đồ bằng `fl_chart`.

### 1.5. Cảnh báo ngân sách

Ứng dụng có cấu trúc dữ liệu cảnh báo trong Firestore:

```txt
users/{uid}/alerts/{alertId}
```

Cảnh báo dùng để lưu các thông tin như ngân sách gần vượt, đã vượt hoặc các nhắc nhở tài chính khác.

### 1.6. Chatbot AI phân tích chi tiêu

Chatbot sử dụng dữ liệu `entries` và `budgets` của người dùng hiện tại để phân tích chi tiêu cá nhân.

Luồng chính:

```txt
Flutter app
  → lấy Firebase ID token của user đang đăng nhập
  → gửi request đến PocketStory API
  → backend verify Firebase ID token
  → backend đọc entries và budgets trong Firestore
  → backend tóm tắt dữ liệu
  → backend gọi Gemini API
  → trả kết quả phân tích về app
```

Endpoint chatbot:

```txt
POST /api/chatbot/analyze
```

Health check endpoint:

```txt
GET /health
```

---

## 2. Công nghệ sử dụng

### 2.1. Mobile app

- Flutter.
- Dart SDK `>=3.4.0 <4.0.0`.
- Firebase Core.
- Firebase Auth.
- Cloud Firestore.
- Firebase Storage.
- Firebase Messaging.
- Google Sign-In.
- Provider.
- HTTP client.
- Image Picker.
- FL Chart.
- Intl.

### 2.2. Backend chatbot

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

### 2.3. Triển khai server

- Ubuntu Server.
- Docker.
- Docker Compose.
- Cloudflare Tunnel.
- Domain public: ví dụ `https://chat.pocketstoryapp.io.vn`.

---

## 3. Cấu trúc thư mục quan trọng

```txt
PocketStoryApp/
├── lib/                         # Source Flutter app
├── assets/                      # Tài nguyên giao diện
├── docs/
│   └── firestore_schema.md      # Mô tả cấu trúc Firestore
├── pocketstory-api/             # Backend chatbot AI
│   ├── src/
│   │   └── index.js             # Entry point Express API
│   ├── package.json
│   ├── Dockerfile
│   ├── .env.example
│   └── .env                     # Không commit file này
├── docker-compose.yml           # Chạy backend + cloudflared bằng Docker Compose
├── pubspec.yaml                 # Cấu hình Flutter dependencies
└── README.md
```

---

## 4. Cài đặt môi trường phát triển

### 4.1. Yêu cầu chung

Cài sẵn các công cụ sau:

- Git.
- Flutter SDK.
- Dart SDK đi kèm Flutter.
- Android Studio hoặc VS Code.
- Firebase CLI nếu cần cấu hình Firebase.
- Node.js `>=20` nếu chạy backend local.
- Docker và Docker Compose nếu deploy bằng container.

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

---

## 5. Chạy Flutter app ở máy local

Clone repo:

```bash
git clone https://github.com/lamdoanh2468/PocketStoryApp.git
cd PocketStoryApp
```

Cài dependencies Flutter:

```bash
flutter pub get
```

Chạy app:

```bash
flutter run
```

Nếu muốn ép app gọi backend chatbot public, chạy với `dart-define`:

```bash
flutter run --dart-define=POCKETSTORY_API_BASE_URL=https://chat.pocketstoryapp.io.vn
```

Khi build APK release:

```bash
flutter build apk --release --dart-define=POCKETSTORY_API_BASE_URL=https://chat.pocketstoryapp.io.vn
```

File APK thường nằm ở:

```txt
build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Chạy backend chatbot local

Vào thư mục backend:

```bash
cd pocketstory-api
```

Tạo file `.env` từ file mẫu:

```bash
cp .env.example .env
```

Ví dụ nội dung `.env`:

```env
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*

FIREBASE_PROJECT_ID=pocketstory-6d696
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json

GEMINI_API_KEY=PASTE_GEMINI_API_KEY_HERE
GEMINI_MODEL=gemini-1.5-flash
```

Cài dependencies:

```bash
npm install
```

Chạy backend ở chế độ development:

```bash
npm run dev
```

Test health check:

```bash
curl http://localhost:3000/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

---

## 7. Triển khai trên Ubuntu Server bằng Docker và Cloudflare Tunnel

Mục tiêu là public backend chatbot ra domain dạng:

```txt
https://chat.pocketstoryapp.io.vn
```

Luồng triển khai:

```txt
Ubuntu Server
  → clone repo PocketStoryApp
  → tạo file .env cần thiết
  → copy Firebase Admin SDK JSON vào server
  → chạy Docker Compose
  → cloudflared tạo tunnel ra Cloudflare
  → domain chat.pocketstoryapp.io.vn trỏ về service pocketstory-api:3000
```

### 7.1. Cài Docker trên Ubuntu Server

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

Kiểm tra Docker:

```bash
sudo docker ps
```

### 7.2. Clone repo

```bash
git clone https://github.com/lamdoanh2468/PocketStoryApp.git
cd PocketStoryApp
```

### 7.3. Tạo file `.env` ở root project

File này dùng cho Docker Compose và Cloudflare Tunnel.

```bash
nano .env
```

Nội dung mẫu:

```env
APP_PORT=3000
CLOUDFLARE_TUNNEL_TOKEN=PASTE_CLOUDFLARE_TUNNEL_TOKEN_HERE
```

Không commit file này lên GitHub.

### 7.4. Tạo file `.env` cho backend API

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

Không commit file này lên GitHub.

### 7.5. Copy Firebase Admin SDK JSON vào server

File Firebase Admin SDK JSON phải nằm trên Ubuntu server, ví dụ:

```txt
~/PocketStoryApp/pocketstory-api/firebase-service-account.json
```

Có thể copy từ Windows sang Ubuntu bằng `scp`:

```bash
scp ./pocketstory-api/firebase-service-account.json username@SERVER_IP:~/PocketStoryApp/pocketstory-api/
```

Kiểm tra file đã có trên server:

```bash
ls -la pocketstory-api/*.json
```

Không commit file Firebase Admin SDK JSON lên GitHub.

### 7.6. Cấu hình Cloudflare Tunnel route

Trong Cloudflare Zero Trust, tạo tunnel và thêm Public Hostname:

```txt
Subdomain: chat
Domain: pocketstoryapp.io.vn
Service: http://pocketstory-api:3000
```

Kết quả route:

```txt
https://chat.pocketstoryapp.io.vn → http://pocketstory-api:3000
```

Lý do dùng `pocketstory-api:3000` là vì `cloudflared` và `pocketstory-api` chạy chung Docker Compose network, nên container `cloudflared` có thể gọi container API bằng service name.

### 7.7. Docker Compose mẫu

Nếu cần deploy backend trong repo này, `docker-compose.yml` nên có dạng:

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

Lưu ý: nếu tên file JSON của bạn khác `firebase-service-account.json`, hãy sửa lại đường dẫn trong phần `volumes`.

### 7.8. Chạy Docker Compose

```bash
cd ~/PocketStoryApp
sudo docker compose down
sudo docker compose up -d --build
```

Kiểm tra container:

```bash
sudo docker ps
```

Bạn cần thấy 2 container đang chạy:

```txt
pocketstory-api
pocketstory-cloudflared
```

Xem log backend:

```bash
sudo docker logs -f pocketstory-api
```

Xem log tunnel:

```bash
sudo docker logs -f pocketstory-cloudflared
```

---

## 8. Test API sau khi deploy

### 8.1. Test local trên Ubuntu server

```bash
curl http://localhost:3000/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

### 8.2. Test qua domain Cloudflare

```bash
curl https://chat.pocketstoryapp.io.vn/health
```

Kết quả đúng:

```json
{"status":"ok","service":"pocketstory-api"}
```

### 8.3. Test endpoint chatbot khi chưa có Firebase token

```bash
curl -X POST https://chat.pocketstoryapp.io.vn/api/chatbot/analyze \
  -H "Content-Type: application/json" \
  -d '{"question":"Phân tích chi tiêu của tôi trong 30 ngày gần đây","rangeDays":30}'
```

Nếu nhận được lỗi sau thì backend vẫn đang hoạt động đúng, vì endpoint này yêu cầu Firebase ID token:

```json
{"message":"Missing Firebase ID token."}
```

### 8.4. Test endpoint chatbot với Firebase ID token

```bash
curl -X POST https://chat.pocketstoryapp.io.vn/api/chatbot/analyze \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer FIREBASE_ID_TOKEN_CUA_USER" \
  -d '{"question":"Phân tích chi tiêu của tôi trong 30 ngày gần đây","rangeDays":30}'
```

Nếu token hợp lệ, backend sẽ đọc dữ liệu của user trong Firestore, gọi AI và trả về kết quả phân tích.

---

## 9. Flow tổng thể của hệ thống

### 9.1. Flow đăng nhập

```txt
Người dùng mở app
  → đăng nhập bằng email/password hoặc Google
  → Firebase Authentication xác thực
  → app lấy thông tin user hiện tại
  → dữ liệu user được lưu/cập nhật trong Firestore
```

### 9.2. Flow ghi nhận thu/chi

```txt
Người dùng nhập khoản thu/chi
  → chọn loại giao dịch
  → nhập số tiền, danh mục, ghi chú, ngày phát sinh
  → có thể chọn hình ảnh
  → app lưu dữ liệu vào Firestore theo users/{uid}/entries
  → UI realtime cập nhật danh sách giao dịch và thống kê
```

### 9.3. Flow quản lý ngân sách

```txt
Người dùng tạo ngân sách
  → chọn danh mục
  → nhập hạn mức
  → chọn khoảng thời gian
  → app lưu vào users/{uid}/budgets
  → hệ thống dùng dữ liệu này để so sánh với chi tiêu thực tế
```

### 9.4. Flow thống kê và báo cáo

```txt
App đọc entries và budgets từ Firestore
  → tổng hợp tổng thu, tổng chi, số dư
  → nhóm chi tiêu theo danh mục
  → tính mức sử dụng ngân sách
  → hiển thị biểu đồ và báo cáo cho người dùng
```

### 9.5. Flow chatbot AI

```txt
Người dùng hỏi chatbot trong Flutter app
  → app lấy Firebase ID token từ user đang đăng nhập
  → app gửi POST /api/chatbot/analyze
  → backend verify token bằng Firebase Admin SDK
  → backend lấy uid từ token
  → backend đọc users/{uid}/entries và users/{uid}/budgets
  → backend tóm tắt dữ liệu thu/chi
  → backend gửi prompt đến Gemini API
  → Gemini trả nội dung phân tích
  → backend trả JSON về Flutter app
  → app hiển thị câu trả lời trong màn hình chatbot
```

### 9.6. Flow deploy bằng Cloudflare Tunnel

```txt
Internet user
  → truy cập https://chat.pocketstoryapp.io.vn
  → Cloudflare nhận request
  → Cloudflare Tunnel chuyển request về cloudflared container trên Ubuntu server
  → cloudflared gọi http://pocketstory-api:3000
  → Express backend xử lý request
  → response quay lại Cloudflare
  → response trả về Flutter app hoặc trình duyệt
```

---

## 10. Build và cập nhật server

Khi code mới được merge vào `main`, cập nhật trên Ubuntu server:

```bash
cd ~/PocketStoryApp
git pull origin main
sudo docker compose down
sudo docker compose up -d --build
```

Kiểm tra lại:

```bash
sudo docker ps
curl https://chat.pocketstoryapp.io.vn/health
```

---

## 11. Các lỗi thường gặp

### 11.1. Docker báo không tìm thấy file `.env`

Lỗi ví dụ:

```txt
env file .../pocketstory-api/.env not found
```

Cách xử lý:

```bash
nano pocketstory-api/.env
```

Sau đó thêm đủ biến môi trường cho backend.

### 11.2. Docker không pull được image do DNS

Lỗi ví dụ:

```txt
lookup registry-1.docker.io ... i/o timeout
```

Có thể sửa DNS cho Docker:

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

### 11.3. Backend báo thiếu Firebase credential

Lỗi thường gặp:

```txt
Failed to read credentials from file
```

Cách xử lý:

- Kiểm tra file Firebase Admin SDK JSON đã có trên Ubuntu server chưa.
- Kiểm tra đường dẫn `GOOGLE_APPLICATION_CREDENTIALS` trong `.env`.
- Kiểm tra phần `volumes` trong `docker-compose.yml`.

### 11.4. Chatbot trả `Missing Firebase ID token`

Điều này là bình thường nếu gọi API bằng `curl` mà chưa truyền token.

Endpoint chatbot bắt buộc có header:

```txt
Authorization: Bearer FIREBASE_ID_TOKEN_CUA_USER
```

Flutter app cần đăng nhập Firebase trước, sau đó lấy ID token và gửi kèm request.

### 11.5. Cloudflare Tunnel Healthy nhưng domain không chạy

Kiểm tra các điểm sau:

- Public Hostname đã đúng domain chưa.
- Service trong Cloudflare có đúng là `http://pocketstory-api:3000` không.
- Container `pocketstory-api` có đang chạy không.
- Container `pocketstory-cloudflared` có đang chạy không.
- `curl http://localhost:3000/health` trên Ubuntu có trả `status: ok` không.

---

## 12. Lưu ý bảo mật

Không commit các file hoặc giá trị sau lên GitHub:

- `.env`.
- Firebase Admin SDK JSON.
- Gemini API key.
- Cloudflare Tunnel token.
- Private key hoặc credential cá nhân.

Nếu lỡ public secret, cần revoke hoặc rotate secret ngay.

---

## 13. Tóm tắt nhanh luồng chạy thật

```txt
1. User đăng nhập Firebase trong Flutter app.
2. User nhập dữ liệu thu/chi, ngân sách.
3. Dữ liệu được lưu vào Firestore theo users/{uid}.
4. User hỏi chatbot.
5. Flutter lấy Firebase ID token.
6. Flutter gọi https://chat.pocketstoryapp.io.vn/api/chatbot/analyze.
7. Cloudflare Tunnel chuyển request về Ubuntu server.
8. Backend Node.js verify token và đọc dữ liệu Firestore.
9. Backend gọi Gemini để phân tích.
10. Flutter hiển thị câu trả lời cho user.
```

---

## 14. Trạng thái triển khai đề xuất

- Flutter app: chạy trên thiết bị người dùng.
- Firebase: quản lý Auth, Firestore, Storage, Messaging.
- Ubuntu Server: chạy `pocketstory-api` và `cloudflared` bằng Docker Compose.
- Cloudflare Tunnel: public backend qua domain HTTPS mà không cần mở port router.
- Domain chatbot: `https://chat.pocketstoryapp.io.vn`.
