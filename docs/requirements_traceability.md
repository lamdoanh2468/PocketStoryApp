# Requirements Traceability

| Yêu cầu | Thành phần trong project |
|---|---|
| Cross-platform Mobile App Android/iOS | Flutter project, `pubspec.yaml`, cấu trúc `lib/` |
| Front-end Flutter | `lib/screens`, `lib/widgets`, `lib/theme` |
| Firebase Auth | `lib/services/auth_service.dart`, `lib/screens/auth/auth_screen.dart` |
| Cloud Firestore | `lib/services/finance_repository.dart`, `firestore.rules` |
| Firebase Storage | `lib/services/storage_service.dart`, `storage.rules` |
| Firebase Cloud Messaging | `lib/services/notification_service.dart`, `functions/index.js` |
| Đăng ký/đăng nhập Email/Google | `AuthScreen`, `AuthService` |
| Quản lý thu nhập | `AddEntryScreen`, `DashboardScreen`, `MoneyEntry` với `EntryType.income` |
| Quản lý ngân sách cá nhân | `BudgetScreen`, `Budget` model |
| Ghi nhận chi tiêu bằng số tiền, ảnh, ghi chú | `AddEntryScreen`, `StorageService`, `MoneyEntry` |
| Thống kê, biểu đồ, báo cáo | `ReportScreen`, `AnalysisService`, `fl_chart` |
| So sánh chi tiêu theo thời gian | `ReportScreen` phần so sánh tháng hiện tại/tháng trước |
| Cảnh báo vượt ngân sách | `AnalysisService.budgetAlerts`, `functions/index.js` |
| Cài đặt qua APK/TestFlight | README phần build APK/IPA |
