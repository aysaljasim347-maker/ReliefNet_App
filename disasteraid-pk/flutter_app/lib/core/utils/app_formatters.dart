import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat pkr = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  );

  static final DateFormat date = DateFormat('dd/MM/yyyy');
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy, hh:mm a');

  static int pkrInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    final cleaned = value.toString().replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;
    return num.tryParse(cleaned)?.round() ?? 0;
  }

  static String pkrAmount(dynamic value) => pkr.format(pkrInt(value));

  static DateTime parseDate(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return value;
    if (value == null) return fallback ?? DateTime.now();
    return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
  }

  static DateTime? tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String formatDate(dynamic value) => date.format(parseDate(value));

  static String formatDateTime(dynamic value) => dateTime.format(parseDate(value));

  static String initial(dynamic value, String fallback) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text.substring(0, 1).toUpperCase();
  }

  static bool isValidPakistanPhone(String value) => RegExp(r'^03\d{9}$').hasMatch(value);
}
