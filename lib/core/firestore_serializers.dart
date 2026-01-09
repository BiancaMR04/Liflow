import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helpers for converting between Firestore types and Dart types.
///
/// Keep these in one place so models remain consistent and easy to evolve.
class FirestoreSerializers {
  static DateTime? dateTimeFromTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static Timestamp? timestampFromDateTime(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  static String? stringOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static bool boolOrFalse(Object? value) {
    if (value is bool) return value;
    return false;
  }

  static Map<String, dynamic> mapOrEmpty(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
