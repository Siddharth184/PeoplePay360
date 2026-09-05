import 'api_client.dart';

class UserManagementService {
  static Future<ApiResponse<List<Map<String, dynamic>>>> getUsers({
    String? role,
    bool? isActive,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (role != null && role.isNotEmpty && role != 'All') query['role'] = role;
    if (isActive != null) query['is_active'] = isActive;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await ApiClient.get<List<Map<String, dynamic>>>(
      '/users',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );

    return response;
  }

  static Future<ApiResponse<Map<String, dynamic>>> createUser(Map<String, dynamic> data) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '/users',
      body: data,
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateUser(String userId, Map<String, dynamic> data) async {
    return await ApiClient.patch<Map<String, dynamic>>(
      '/users/$userId',
      body: data,
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> toggleUserActive(String userId, bool isActive) async {
    return await ApiClient.patch<Map<String, dynamic>>(
      '/users/$userId',
      body: {'is_active': isActive},
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
