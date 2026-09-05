import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final bool isSuccess;
  final int statusCode;
  final T? data;
  final String? errorMessage;
  final dynamic rawJson;

  ApiResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorMessage,
    this.rawJson,
  });

  factory ApiResponse.success(T data, {int statusCode = 200, dynamic rawJson}) {
    return ApiResponse(
      isSuccess: true,
      statusCode: statusCode,
      data: data,
      rawJson: rawJson,
    );
  }

  factory ApiResponse.failure(String message, {int statusCode = 500, dynamic rawJson}) {
    return ApiResponse(
      isSuccess: false,
      statusCode: statusCode,
      errorMessage: message,
      rawJson: rawJson,
    );
  }
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Configurable base URL
  static String baseUrl = 'http://127.0.0.1:8000/api/v1';

  // Active Session Data
  static String? token;
  static String? currentUserId;
  static String? currentEmail;
  static String? currentUserRole;
  static String? currentEmployeeId;
  static String? currentEmployeeName;
  static List<String> currentPermissions = [];

  // Connectivity flag
  static bool isBackendOnline = true;

  static void setSession({
    required String accessToken,
    required String userId,
    required String email,
    required String role,
    String? employeeId,
    String? employeeName,
    List<String> permissions = const [],
  }) {
    token = accessToken;
    currentUserId = userId;
    currentEmail = email;
    currentUserRole = role;
    currentEmployeeId = employeeId;
    currentEmployeeName = employeeName;
    currentPermissions = List<String>.from(permissions);
    isBackendOnline = true;
  }

  static void clearSession() {
    token = null;
    currentUserId = null;
    currentEmail = null;
    currentUserRole = null;
    currentEmployeeId = null;
    currentEmployeeName = null;
    currentPermissions = [];
  }

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  static Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = <String, String>{};
      queryParams.forEach((key, value) {
        if (value != null) {
          stringParams[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  static Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? parser,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      developer.log('GET $uri', name: 'ApiClient');
      final response = await http.get(uri, headers: _buildHeaders(extraHeaders: headers)).timeout(timeout);
      isBackendOnline = true;
      return _handleResponse<T>(response, parser);
    } catch (e, st) {
      developer.log('GET error: $e', name: 'ApiClient', error: e, stackTrace: st);
      isBackendOnline = false;
      return ApiResponse.failure('Connection error: $e', statusCode: 0);
    }
  }

  static Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? parser,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final encodedBody = body != null ? jsonEncode(body) : null;
      developer.log('POST $uri', name: 'ApiClient');
      final response = await http
          .post(uri, headers: _buildHeaders(extraHeaders: headers), body: encodedBody)
          .timeout(timeout);
      isBackendOnline = true;
      return _handleResponse<T>(response, parser);
    } catch (e, st) {
      developer.log('POST error: $e', name: 'ApiClient', error: e, stackTrace: st);
      isBackendOnline = false;
      return ApiResponse.failure('Connection error: $e', statusCode: 0);
    }
  }

  static Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? parser,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final encodedBody = body != null ? jsonEncode(body) : null;
      developer.log('PUT $uri', name: 'ApiClient');
      final response = await http
          .put(uri, headers: _buildHeaders(extraHeaders: headers), body: encodedBody)
          .timeout(timeout);
      isBackendOnline = true;
      return _handleResponse<T>(response, parser);
    } catch (e, st) {
      developer.log('PUT error: $e', name: 'ApiClient', error: e, stackTrace: st);
      isBackendOnline = false;
      return ApiResponse.failure('Connection error: $e', statusCode: 0);
    }
  }

  static Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? parser,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final encodedBody = body != null ? jsonEncode(body) : null;
      developer.log('PATCH $uri', name: 'ApiClient');
      final response = await http
          .patch(uri, headers: _buildHeaders(extraHeaders: headers), body: encodedBody)
          .timeout(timeout);
      isBackendOnline = true;
      return _handleResponse<T>(response, parser);
    } catch (e, st) {
      developer.log('PATCH error: $e', name: 'ApiClient', error: e, stackTrace: st);
      isBackendOnline = false;
      return ApiResponse.failure('Connection error: $e', statusCode: 0);
    }
  }

  static Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    T Function(dynamic json)? parser,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      developer.log('DELETE $uri', name: 'ApiClient');
      final response = await http
          .delete(uri, headers: _buildHeaders(extraHeaders: headers))
          .timeout(timeout);
      isBackendOnline = true;
      return _handleResponse<T>(response, parser);
    } catch (e, st) {
      developer.log('DELETE error: $e', name: 'ApiClient', error: e, stackTrace: st);
      isBackendOnline = false;
      return ApiResponse.failure('Connection error: $e', statusCode: 0);
    }
  }

  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? parser,
  ) {
    developer.log('Response [${response.statusCode}]', name: 'ApiClient');
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      T? parsedData;
      if (parser != null && decoded != null) {
        try {
          parsedData = parser(decoded);
        } catch (e, st) {
          developer.log('Parser error: $e', name: 'ApiClient', error: e, stackTrace: st);
          return ApiResponse.failure(
            'Data parsing error: $e',
            statusCode: response.statusCode,
            rawJson: decoded,
          );
        }
      } else if (decoded is T) {
        parsedData = decoded;
      }

      return ApiResponse.success(
        parsedData as T,
        statusCode: response.statusCode,
        rawJson: decoded,
      );
    }

    // Extract error detail from FastAPI response if present
    String errorMsg = 'HTTP ${response.statusCode}';
    if (decoded is Map && decoded.containsKey('detail')) {
      final detail = decoded['detail'];
      if (detail is String) {
        errorMsg = detail;
      } else if (detail is List && detail.isNotEmpty) {
        errorMsg = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
      }
    } else if (decoded is String && decoded.isNotEmpty) {
      errorMsg = decoded;
    }

    return ApiResponse.failure(
      errorMsg,
      statusCode: response.statusCode,
      rawJson: decoded,
    );
  }
}
