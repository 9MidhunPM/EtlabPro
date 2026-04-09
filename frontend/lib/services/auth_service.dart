import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _rollNumber;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;

  String? get rollNumber    => _rollNumber;
  bool   get isLoggedIn     => _rollNumber != null && _accessToken != null;
  bool   get isLoading      => _isLoading;
  String? get error         => _error;
  String? get accessToken   => _accessToken;

  /// Restore session from secure storage on app start.
  Future<void> restoreSession() async {
    final roll    = await _storage.read(key: AppConstants.kRollNumber);
    final access  = await _storage.read(key: AppConstants.kAccessToken);
    final refresh = await _storage.read(key: AppConstants.kRefreshToken);
    if (roll != null && access != null) {
      _rollNumber   = roll;
      _accessToken  = access;
      _refreshToken = refresh;
      ApiClient.instance.setAccessToken(access);
      notifyListeners();
    }
  }

  /// Login via POST /auth/login (public endpoint, no token needed).
  /// Returns JWT access + refresh tokens.
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.publicPost('/auth/login', {
        'username': username,
        'password': password,
      });

      final roll    = data['roll_number'] as String;
      final access  = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;

      await Future.wait([
        _storage.write(key: AppConstants.kUsername,     value: username),
        _storage.write(key: AppConstants.kPassword,     value: password),
        _storage.write(key: AppConstants.kRollNumber,   value: roll),
        _storage.write(key: AppConstants.kAccessToken,  value: access),
        _storage.write(key: AppConstants.kRefreshToken, value: refresh),
      ]);

      _rollNumber   = roll;
      _accessToken  = access;
      _refreshToken = refresh;
      ApiClient.instance.setAccessToken(access);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error     = e.isUnauthorized ? 'Invalid username or password.' : e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error     = 'Could not reach the server. Check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh the access token using the refresh token.
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final data = await ApiClient.instance.publicPost('/auth/refresh', {
        'refresh_token': _refreshToken!,
      });
      final newAccess = data['access_token'] as String;
      _accessToken = newAccess;
      ApiClient.instance.setAccessToken(newAccess);
      await _storage.write(key: AppConstants.kAccessToken, value: newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Force resync all data (scrape from college again).
  Future<void> resync() async {
    final username = await _storage.read(key: AppConstants.kUsername);
    final password = await _storage.read(key: AppConstants.kPassword);
    if (username == null || password == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/sync-all', {
        'username': username,
        'password': password,
        'force': true,
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          try {
            await ApiClient.instance.post('/sync-all', {
              'username': username,
              'password': password,
              'force': true,
            });
          } catch (_) {}
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _rollNumber = _accessToken = _refreshToken = null;
    ApiClient.instance.setAccessToken(null);
    notifyListeners();
  }
}
