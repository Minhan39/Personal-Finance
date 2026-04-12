import 'api_environment.dart';

class ApiConfig {
  static final Map<ApiDomain, String> baseUrls = {
    ApiDomain.gold: 'http://api.btmc.vn',
  };

  static String getBaseUrl(ApiDomain domain) {
    return baseUrls[domain]!;
  }
}