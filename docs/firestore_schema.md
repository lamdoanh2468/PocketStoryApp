# Firestore Schema

Dữ liệu được tách theo user để bảo mật và đồng bộ theo tài khoản đăng nhập.

```txt
users/{uid}
  displayName: string
  email: string
  photoUrl: string?
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/entries/{entryId}
  id: string
  uid: string
  type: "income" | "expense"
  amount: number
  category: string
  note: string
  imageUrl: string?
  imagePath: string?
  happenedAt: timestamp
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/budgets/{budgetId}
  id: string
  category: string
  limitAmount: number
  periodStart: timestamp
  periodEnd: timestamp
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/fcmTokens/{token}
  token: string
  platform: string
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/alerts/{alertId}
  title: string
  body: string
  category: string
  ratio: number
  createdAt: timestamp
  read: boolean
```

## Lý do chọn subcollection theo user

- Rules dễ viết: user chỉ đọc/ghi dữ liệu của chính mình.
- Dữ liệu tài chính riêng tư không bị trộn giữa các tài khoản.
- Dễ đồng bộ realtime bằng stream của Firestore.
- Phù hợp MVP, không cần backend riêng ngoài Firebase.
