import 'package:flutter/material.dart';
import 'package:personal_finance/core/api/api_client.dart';
import 'package:personal_finance/core/api/api_endpoints.dart';

import '../core/api/api_environment.dart';
import '../models/gold.dart';

class GoldService {
  static final ApiClient _client = ApiClient(ApiDomain.gold);

  static Future<List<Gold>> getGolds() async {
    final response = await _client.dio.get(
      GoldEndpoints.price,
      queryParameters: {'key': '3kd8ub1llcg9t45hnoh8hmn7t5kc2v'},
    );

    final List list = response.data['DataList']['Data'];

    return list.map((e) => Gold.fromMap(e as Map<String, dynamic>)).toList();
  }
}
