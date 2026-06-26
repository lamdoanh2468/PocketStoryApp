# Platform Permissions

Sau khi chạy `flutter create .` hoặc `flutterfire configure`, kiểm tra thêm quyền sau.

## Android - android/app/src/main/AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## iOS - ios/Runner/Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>PocketStory cần camera để chụp ảnh khoản chi.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>PocketStory cần truy cập thư viện ảnh để đính kèm hình ảnh chi tiêu.</string>
```
