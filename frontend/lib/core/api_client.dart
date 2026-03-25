import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// HTTP client that uses JWT Bearer tokens for authentication.
/// Public endpoints (login, refresh) don't need a token.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      h['Authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  // ── Public POST (no auth needed) ─────────────────────────────────

  Future<dynamic> publicPost(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.apiV1}$path');
    final res = await http
        .post(uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    return _decode(res);
  }

  // ── GET ──────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('${AppConstants.apiV1}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  // ── POST ─────────────────────────────────────────────────────────

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.apiV1}$path');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    return _decode(res);
  }

  // ── Helpers ──────────────────────────────────────────────────────

  dynamic _decode(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(body);
    }
    String detail = 'HTTP ${res.statusCode}';
    try {
      detail = (jsonDecode(body) as Map)['detail'] ?? detail;
    } catch (_) {}
    throw ApiException(res.statusCode, detail);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound     => statusCode == 404;
}
