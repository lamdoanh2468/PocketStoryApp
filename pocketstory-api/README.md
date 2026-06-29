# PocketStory API

Backend riêng cho chatbot phân tích chi tiêu cá nhân của PocketStory. Backend này thay cho Firebase Functions, nên không cần bật Firebase Blaze chỉ để chạy chatbot.

## Luồng xử lý

1. Flutter lấy Firebase ID token của user hiện tại.
2. Flutter gọi `POST /api/chatbot/analyze` và gửi token trong header `Authorization: Bearer <id-token>`.
3. Backend verify token bằng Firebase Admin SDK.
4. Backend lấy `uid` từ token đã verify.
5. Backend đọc Firestore:
   - `users/{uid}/entries`
   - `users/{uid}/budgets`
6. Backend tóm tắt dữ liệu thu/chi/ngân sách.
7. Backend gọi OpenAI API bằng `OPENAI_API_KEY` trong `.env`.
8. Backend trả kết quả phân tích về Flutter.

## Chạy local

```bash
cd pocketstory-api
npm install
cp .env.example .env
npm run dev
```

Sau đó API chạy ở:

```text
http://localhost:3000
```

Kiểm tra health:

```bash
curl http://localhost:3000/health
```

## Cấu hình `.env`

```env
PORT=3000
CORS_ORIGIN=*
FIREBASE_PROJECT_ID=pocketstory-6d696
GOOGLE_APPLICATION_CREDENTIALS=C:\\path\\to\\service-account.json
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-4.1-mini
```

Không commit `.env` hoặc file service account lên GitHub.

## Lấy Firebase service account

Vào Firebase Console:

Project settings → Service accounts → Generate new private key

Tải file JSON về máy/server rồi trỏ `GOOGLE_APPLICATION_CREDENTIALS` tới file đó.

## Chạy bằng Docker

```bash
docker build -t pocketstory-api .
docker run --env-file .env -p 3000:3000 pocketstory-api
```

Nếu dùng Cloudflare Tunnel, trỏ domain API của bạn về container đang chạy port `3000`.

## Flutter base URL

Khi chạy Android Emulator:

```bash
flutter run --dart-define=POCKETSTORY_API_BASE_URL=http://10.0.2.2:3000
```

Khi chạy điện thoại thật hoặc build APK, dùng domain backend:

```bash
flutter run --dart-define=POCKETSTORY_API_BASE_URL=https://api.your-domain.com
```
