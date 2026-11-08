import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

class SaveService {
  static final _scopes = [SheetsApi.spreadsheetsReadonlyScope];

  static Future<List<List<Object?>>?> readSheet() async {
    final credentialsJson = await rootBundle.loadString(
      'assets/credentials.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(
      json.decode(credentialsJson),
    );

    final authClient = await clientViaServiceAccount(credentials, _scopes);
    final sheetsApi = SheetsApi(authClient);

    final spreadsheetId = '1PbOqvtbjfB1tw1cvNYZYGWXnmhc0ezQQ9pzGR3P99PA';
    final range = 'save_money';

    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      range,
    );
    return response.values;
  }
}
