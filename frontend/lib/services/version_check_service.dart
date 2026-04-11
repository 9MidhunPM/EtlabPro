import '../core/api_client.dart';
import '../core/constants.dart';

class VersionCheckResult {
  final bool isOutdated;
  final String currentVersion;
  final String latestVersion;

  const VersionCheckResult({
    required this.isOutdated,
    required this.currentVersion,
    required this.latestVersion,
  });
}

class VersionCheckService {
  VersionCheckService._();

  static Future<VersionCheckResult> check() async {
    final current = AppConstants.appVersion;
    if (current.isEmpty) {
      return const VersionCheckResult(
        isOutdated: false,
        currentVersion: '',
        latestVersion: '',
      );
    }

    try {
      final res = await ApiClient.instance.get('/meta/latest-version');
      final latest = (res is Map<String, dynamic>)
          ? (res['latest_version']?.toString().trim() ?? '')
          : '';

      if (latest.isEmpty) {
        return VersionCheckResult(
          isOutdated: false,
          currentVersion: current,
          latestVersion: '',
        );
      }

      return VersionCheckResult(
        isOutdated: current != latest,
        currentVersion: current,
        latestVersion: latest,
      );
    } catch (_) {
      return VersionCheckResult(
        isOutdated: false,
        currentVersion: current,
        latestVersion: '',
      );
    }
  }
}
