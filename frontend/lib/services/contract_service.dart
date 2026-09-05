import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class ContractService {
  static Future<ApiResponse<List<ContractModel>>> getContracts({
    String? employeeId,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await ApiClient.get<List<ContractModel>>(
      '/contracts',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => ContractModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.contracts);
    }

    return response;
  }

  static Future<ApiResponse<ContractModel>> getContract(String id) async {
    final response = await ApiClient.get<ContractModel>(
      '/contracts/$id',
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final found = MockDataService.contracts.firstWhere(
        (c) => c.id == id,
        orElse: () => MockDataService.contracts.first,
      );
      return ApiResponse.success(found);
    }

    return response;
  }

  static Future<ApiResponse<ContractModel>> createContract(Map<String, dynamic> data) async {
    return await ApiClient.post<ContractModel>(
      '/contracts',
      body: data,
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<ContractModel>> updateContract(String id, Map<String, dynamic> data) async {
    return await ApiClient.put<ContractModel>(
      '/contracts/$id',
      body: data,
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<ContractModel>> terminateContract(String id, String dateEnd) async {
    return await ApiClient.post<ContractModel>(
      '/contracts/$id/terminate',
      body: {'date_end': dateEnd},
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
