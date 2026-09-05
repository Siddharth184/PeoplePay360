import '../models/models.dart';
import 'api_client.dart';

class AiCopilotService {
  static Future<ApiResponse<Map<String, dynamic>>> ask({
    required String prompt,
    String? conversationId,
    bool forceEscalate = false,
    String? payslipId,
  }) async {
    final body = <String, dynamic>{
      'prompt': prompt.trim(),
      'force_escalate': forceEscalate,
    };
    if (conversationId != null && conversationId.isNotEmpty) {
      body['conversation_id'] = conversationId;
    }
    if (payslipId != null && payslipId.isNotEmpty) {
      body['payslip_id'] = payslipId;
    }

    final response = await ApiClient.post<Map<String, dynamic>>(
      '/ai/copilot/ask',
      body: body,
      parser: (json) => json as Map<String, dynamic>,
      timeout: const Duration(seconds: 30),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      // Deterministic offline response demo
      return ApiResponse.success({
        'mode': 'TIER0_TEMPLATE',
        'answer': 'PeoplePay360 Copilot (Offline Mode): We provide end-to-end payroll computation, leave allocation, attendance tracking, and AST-safe salary engine evaluation.',
        'confidence': 0.95,
        'intent': 'HR_POLICY_OVERVIEW',
        'citations': [
          {'title': 'Company Handbook 2026', 'score': 0.95, 'collection': 'policy', 'human_verified': true}
        ],
        'escalation_available': true,
      });
    }

    return response;
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getConversations() async {
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/ai/copilot/conversations',
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> getConversation(String id) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '/ai/copilot/conversations/$id',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<List<EscalationTicketModel>>> getEscalations({
    String? status,
    String? category,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (category != null && category.isNotEmpty) query['category'] = category;

    final response = await ApiClient.get<List<EscalationTicketModel>>(
      '/ai/escalations',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => EscalationTicketModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success([
        EscalationTicketModel(
          id: 'esc-01',
          ticketNo: 'ESC-2026-0001',
          questionText: 'Can I carry forward my unused 4 days of PTO into Q3?',
          category: 'LEAVE_POLICY',
          status: 'OPEN',
          priority: 'NORMAL',
          slaDueAt: '2026-09-06T18:00:00Z',
          retrievalConfidence: 0.42,
        )
      ]);
    }

    return response;
  }

  static Future<ApiResponse<Map<String, dynamic>>> resolveEscalation(String escalationId, String answer) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '/ai/escalations/$escalationId/resolve',
      body: {'answer': answer},
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
