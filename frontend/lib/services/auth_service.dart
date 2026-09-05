import 'api_client.dart';
import 'mock_data_service.dart';
import 'employee_service.dart';

class AuthService {
  /// Offline / dev credential store. Lets a changed password be enforced on the
  /// next login within the running app session when no backend is reachable.
  /// Seeded with the demo accounts (all share the same demo password).
  static const String _defaultDemoPassword = 'PeoplePay@360';
  static final Map<String, String> _localCredentials = {
    'admin@oxp.com': _defaultDemoPassword,
    'sara.khan@oxp.com': _defaultDemoPassword,
    'vikram.nair@oxp.com': _defaultDemoPassword,
    'aarav.mehta@oxp.com': _defaultDemoPassword,
    'rohan.desai@oxp.com': _defaultDemoPassword,
  };

  static void _rememberCredential(String email, String password) {
    final key = email.toLowerCase().trim();
    if (key.isEmpty || password.isEmpty) return;
    _localCredentials[key] = password;
  }

  /// Returns the current password known for this email (or the default demo password).
  static String getKnownPassword(String email) {
    final key = email.toLowerCase().trim();
    return _localCredentials[key] ?? _defaultDemoPassword;
  }

  static Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      _rememberCredential(email, password);
      final data = response.data!;
      final backendRole = data['role']?.toString() ?? 'EMPLOYEE';
      final backendName = data['employee_name']?.toString();
      final backendEmpId = data['employee_id']?.toString();

      final resolvedEmp = MockDataService.getEmployeeForUser(
        email: email,
        role: backendRole,
        name: backendName,
      );
      MockDataService.switchActiveUser(resolvedEmp);
      EmployeeService.currentEmployeeNotifier.value = resolvedEmp;

      ApiClient.setSession(
        accessToken: data['access_token']?.toString() ?? '',
        userId: data['user_id']?.toString() ?? '',
        email: email,
        role: backendRole,
        employeeId: backendEmpId ?? resolvedEmp.id,
        employeeName: backendName ?? resolvedEmp.name,
        permissions: (data['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
      return response;
    }

    // If backend connection fails (e.g. offline dev mode), provide clean fallback
    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final cleanEmail = email.toLowerCase().trim();

      // Enforce a locally changed password: if we have a stored credential for
      // this account, the entered password must match it. This makes a reset
      // done via "Forgot Password" actually take effect on the next login.
      final knownPassword = _localCredentials[cleanEmail] ?? _defaultDemoPassword;
      if (password != knownPassword) {
        return ApiResponse.failure('Incorrect email or password.', statusCode: 401);
      }
      _rememberCredential(email, password);

      String fallbackRole = 'EMPLOYEE';
      if (cleanEmail.contains('admin')) {
        fallbackRole = 'ADMIN';
      } else if (cleanEmail.contains('sara') || cleanEmail.contains('hr')) {
        fallbackRole = 'HR_MANAGER';
      } else if (cleanEmail.contains('payroll') || cleanEmail.contains('vikram')) {
        fallbackRole = 'HR_PAYROLL_MANAGER';
      } else if (cleanEmail.contains('aarav')) {
        fallbackRole = 'HR_PAYROLL_USER';
      }

      final resolvedEmp = MockDataService.getEmployeeForUser(
        email: cleanEmail,
        role: fallbackRole,
      );
      MockDataService.switchActiveUser(resolvedEmp);
      EmployeeService.currentEmployeeNotifier.value = resolvedEmp;

      ApiClient.setSession(
        accessToken: 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'usr_mock_01',
        email: email,
        role: fallbackRole,
        employeeId: resolvedEmp.id,
        employeeName: resolvedEmp.name,
        permissions: ['*'],
      );

      return ApiResponse.success({
        'access_token': 'mock_jwt_token',
        'role': fallbackRole,
        'user_id': 'usr_mock_01',
        'employee_id': resolvedEmp.id,
        'employee_name': resolvedEmp.name,
        'permissions': ['*'],
      });
    }

    return response;
  }

  static Future<ApiResponse<Map<String, dynamic>>> getMe() async {
    return await ApiClient.get<Map<String, dynamic>>(
      '/auth/me',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '/auth/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required String email,
  }) async {
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      body: {'email': email.trim()},
      parser: (json) => json as Map<String, dynamic>,
    );

    // If offline or dev fallback mode
    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success({
        'detail': 'If an active account exists for $email, an encrypted password reset link has been dispatched.',
      });
    }

    return response;
  }

  /// Verifies the user's *current* password before allowing a reset.
  /// Online it probes /auth/login (then discards the session); offline it
  /// checks the local credential store.
  static Future<ApiResponse<bool>> verifyCurrentPassword({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess) {
      // This was only a verification probe; do not keep the session.
      ApiClient.clearSession();
      _rememberCredential(email, password);
      return ApiResponse.success(true);
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final known = _localCredentials[email.toLowerCase().trim()] ?? _defaultDemoPassword;
      if (password == known) {
        return ApiResponse.success(true);
      }
      return ApiResponse.failure('Current password is incorrect.', statusCode: 401);
    }

    return ApiResponse.failure(
      response.errorMessage ?? 'Current password is incorrect.',
      statusCode: response.statusCode,
    );
  }

  /// Resets the password after the previous password has been verified.
  /// Sends both current + new to the backend, which re-verifies ownership.
  static Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/auth/reset-password',
      body: {
        'email': email.trim(),
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess) {
      // Persist locally so the next login (online or offline) uses the new one.
      _rememberCredential(email, newPassword);
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final key = email.toLowerCase().trim();
      final known = _localCredentials[key] ?? _defaultDemoPassword;
      if (currentPassword != known) {
        return ApiResponse.failure('Current password is incorrect.', statusCode: 401);
      }
      _rememberCredential(email, newPassword);
      return ApiResponse.success({
        'detail': 'Password updated successfully. Please sign in with your new password.',
      });
    }

    return response;
  }

  static void logout() {
    ApiClient.clearSession();
  }
}
