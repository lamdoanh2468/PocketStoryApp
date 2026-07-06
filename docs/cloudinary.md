# Cloudinary image storage

PocketStoryApp sử dụng Cloudinary để lưu ảnh minh chứng cho các khoản chi của người dùng. Firestore chỉ lưu đường dẫn ảnh và URL ảnh, không lưu trực tiếp file ảnh.

## Mục đích sử dụng

Cloudinary được dùng cho chức năng ghi nhận khoản chi có hình ảnh kèm theo. Khi người dùng chọn ảnh trong màn hình thêm hoặc sửa giao dịch, Flutter app upload ảnh lên Cloudinary, sau đó lưu thông tin ảnh vào document giao dịch trong Cloud Firestore.

Luồng xử lý:

```txt
User chọn ảnh khoản chi
  → Flutter app gọi StorageService.uploadEntryImage(...)
  → Ảnh được upload lên Cloudinary
  → Cloudinary trả về secure_url và public_id
  → App lưu imageUrl và imagePath vào users/{uid}/entries/{entryId}
```

## Cấu hình hiện tại trong Flutter app

File xử lý upload ảnh:

```txt
lib/services/storage_service.dart
```

Các giá trị Cloudinary đang được cấu hình trong `StorageService`:

```dart
static const String _cloudName = 'dijswvhab';
static const String _apiKey = '786533456125142';
static const String _uploadPreset = 'pocket_app';
```

Endpoint upload ảnh:

```txt
https://api.cloudinary.com/v1_1/{cloudName}/image/upload
```

Folder lưu ảnh trên Cloudinary:

```txt
pocketstory/users/{uid}/entries
```

`public_id` của ảnh được đặt theo `entryId`, giúp liên kết ảnh với giao dịch tương ứng.

## Dữ liệu lưu trong Firestore

Trong document giao dịch tại:

```txt
users/{uid}/entries/{entryId}
```

App lưu thêm các trường liên quan đến ảnh:

```txt
imageUrl   URL ảnh do Cloudinary trả về, dùng để hiển thị trong app
imagePath  public_id/path của ảnh trên Cloudinary, dùng cho thao tác quản lý ảnh sau này
```

Ví dụ:

```json
{
  "imageUrl": "https://res.cloudinary.com/.../image/upload/...jpg",
  "imagePath": "pocketstory/users/USER_UID/entries/ENTRY_ID"
}
```

## Lưu ý về xóa ảnh

Hiện tại hàm `deleteEntryImage()` trong `StorageService` chưa xóa ảnh thật trên Cloudinary.

Lý do: để xóa ảnh khỏi Cloudinary cần dùng API secret. API secret không nên đặt trong Flutter app vì app mobile có thể bị dịch ngược và lộ secret.

Cách xử lý đúng trong tương lai:

```txt
Flutter app
  → gọi backend hoặc Cloud Functions
  → backend dùng Cloudinary API secret để xóa ảnh
  → backend trả kết quả về app
```

Vì vậy, hiện tại `deleteEntryImage()` chỉ đóng vai trò điểm mở rộng để sau này chuyển logic xóa ảnh sang backend riêng hoặc Firebase Cloud Functions.

## Khác biệt với Firebase Storage

README cũ có nhắc đến Firebase Storage, nhưng code hiện tại đang upload ảnh giao dịch bằng Cloudinary thông qua `StorageService`.

Có thể hiểu vai trò hiện tại như sau:

```txt
Firebase Authentication  Xác thực người dùng
Cloud Firestore          Lưu dữ liệu thu/chi, ngân sách, cảnh báo
Cloudinary               Lưu ảnh minh chứng giao dịch
Firebase Messaging       Phục vụ thông báo/cảnh báo nếu được cấu hình
```

## Bảo mật

Không nên commit các giá trị sau lên GitHub nếu chuyển sang cơ chế signed upload hoặc xóa ảnh qua backend:

```txt
CLOUDINARY_API_SECRET
CLOUDINARY_URL
Backend .env chứa Cloudinary secret
```

Nếu dùng unsigned upload preset, cần giới hạn preset trong Cloudinary Dashboard, ví dụ giới hạn loại file, kích thước file và thư mục upload để giảm rủi ro bị abuse.
