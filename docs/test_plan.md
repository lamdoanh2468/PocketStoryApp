# Test Plan MVP

## Authentication

- Đăng ký email/password thành công.
- Đăng nhập email/password thành công.
- Đăng nhập Google thành công.
- Đăng xuất và đăng nhập lại vẫn thấy dữ liệu cũ.

## Income / Expense

- Thêm khoản thu không có ảnh.
- Thêm khoản chi có số tiền, danh mục, ghi chú.
- Thêm khoản chi có ảnh từ camera/gallery.
- Xóa khoản chi và kiểm tra báo cáo cập nhật lại.

## Budget

- Tạo ngân sách tháng cho danh mục Ăn uống.
- Chi tiêu dưới 80% ngân sách không cảnh báo nghiêm trọng.
- Chi tiêu từ 80% trở lên hiển thị cảnh báo trong app.
- Chi tiêu vượt 100% ngân sách hiển thị trạng thái vượt ngân sách.

## Report / Compare

- Báo cáo tháng hiện tại tính đúng tổng thu/tổng chi/số dư.
- Biểu đồ theo danh mục hiển thị các khoản chi đúng nhóm.
- So sánh tháng hiện tại và tháng trước trả về tăng/giảm đúng phần trăm.

## Security

- User A không đọc được `users/{uid}` của User B.
- User không đăng nhập không đọc/ghi được Firestore/Storage.
