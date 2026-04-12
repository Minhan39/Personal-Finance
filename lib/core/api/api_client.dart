import 'package:dio/dio.dart';
import 'package:personal_finance/core/api/api_config.dart';
import 'package:personal_finance/core/api/api_environment.dart';

class ApiClient {
  late Dio dio;

  ApiClient(ApiDomain domain) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.getBaseUrl(domain),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }
}
