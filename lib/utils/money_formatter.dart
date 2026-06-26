import 'package:intl/intl.dart';

class MoneyFormatter {
  static final NumberFormat _vnd = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  static String vnd(num value) => _vnd.format(value);
}
