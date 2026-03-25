import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central constants for the EtlabPro app.
class AppConstants {
  AppConstants._();

  /// Base URL of the EtlabPro FastAPI backend.
  static const String _buildTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final raw = (dotenv.env['API_BASE_URL'] ?? _buildTimeBaseUrl).trim();
    String resolved = raw;
    if (resolved.endsWith('/')) {
      resolved = resolved.substring(0, resolved.length - 1);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (resolved.contains('://localhost')) {
        return resolved.replaceFirst('://localhost', '://10.0.2.2');
      }
      if (resolved.contains('://127.0.0.1')) {
        return resolved.replaceFirst('://127.0.0.1', '://10.0.2.2');
      }
    }
    return resolved;
  }

  static String get apiV1 => '$baseUrl/api/v1';

  // Secure-storage keys
  static const String kUsername     = 'etlab_username';
  static const String kPassword    = 'etlab_password';
  static const String kRollNumber  = 'roll_number';
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';

  // Local storage keys (shared_preferences)
  static const String kLocalProfile    = 'local_profile';
  static const String kLocalSummary    = 'local_summary';
  static const String kLocalAttendance = 'local_attendance';
  static const String kLocalMarks      = 'local_marks';
  static const String kLocalUniResults = 'local_uni_results';
  static const String kLocalTimetable  = 'local_timetable';
  static const String kLocalShrNumber  = 'local_shr_number';

  // Cache TTL keys (stored as ISO-8601 timestamps in secure storage)
  static const String kAttendanceTs  = 'cache_attendance_ts';
  static const String kProfileTs     = 'cache_profile_ts';
  static const String kMarksTs       = 'cache_marks_ts';
  static const String kUniResultsTs  = 'cache_uni_results_ts';
  static const String kTimetableTs   = 'cache_timetable_ts';
  static const String kSummaryTs     = 'cache_summary_ts';

  // Cache durations
  static const Duration attendanceTtl = Duration(hours: 2);
  static const Duration defaultTtl    = Duration(days: 7);

  // Period timings
  static const Map<int, Map<String, String>> periodTimings = {
    1: {'start': '09:00', 'end': '10:00', 'display': '9:00 - 10:00 AM'},
    2: {'start': '10:00', 'end': '10:45', 'display': '10:00 - 10:45 AM'},
    3: {'start': '11:00', 'end': '12:00', 'display': '11:00 - 12:00 PM'},
    4: {'start': '12:00', 'end': '12:45', 'display': '12:00 - 12:45 PM'},
    5: {'start': '13:30', 'end': '14:30', 'display': '1:30 - 2:30 PM'},
    6: {'start': '14:30', 'end': '15:30', 'display': '2:30 - 3:30 PM'},
    7: {'start': '15:45', 'end': '16:20', 'display': '3:45 - 4:20 PM'},
  };
}
