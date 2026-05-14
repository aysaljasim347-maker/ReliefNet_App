class SafeDataHandler {
  /// Safely extracts a List from dynamic data.
  /// Handles:
  /// - null -> []
  /// - List -> data
  /// - Map with 'data' key as List -> data['data']
  static List<dynamic> extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final innerData = data['data'];
      if (innerData is List) return innerData;
    }
    return [];
  }

  /// Safely extracts a Map from dynamic data.
  /// Handles:
  /// - null -> {}
  /// - Map<String, dynamic> -> data
  /// - Map with 'data' key as Map -> data['data']
  static Map<String, dynamic> extractMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      final innerData = data['data'];
      if (innerData is Map<String, dynamic>) return innerData;
      if (innerData is Map) return Map<String, dynamic>.from(innerData);
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Safely parses a double from dynamic data.
  static double parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Safely parses an int from dynamic data.
  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }
}
