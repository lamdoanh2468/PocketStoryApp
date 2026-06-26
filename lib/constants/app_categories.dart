class AppCategories {
  static const allBudgetCategory = 'Tất cả';

  static const expense = <String>[
    'Ăn uống',
    'Di chuyển',
    'Học tập',
    'Mua sắm',
    'Giải trí',
    'Cafe',
    'Du lịch',
    'Sức khỏe',
    'Khác',
  ];

  static const income = <String>[
    'Lương',
    'Trợ cấp',
    'Học bổng',
    'Làm thêm',
    'Quà tặng',
    'Khác',
  ];

  static const budget = <String>[
    allBudgetCategory,
    ...expense,
  ];
}
