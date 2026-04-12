import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String?> getFcmToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = await FirebaseMessaging.instance.getToken();
    await prefs.setString('fcmToken', token ?? '');
    return token;
  }

  static Future addLog({
    required String deviceType,
    required String fcmToken,
    required String userId,
    DateTime? time,
  }) async {
    try {
      final log = {
        'deviceType': deviceType,
        'fcmToken': fcmToken,
        'createAtLocal': time ?? DateTime.now(),
        'createAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users/$userId/access_logs').add(log);
    } catch (e) {
      debugPrint('Error add log: $e');
    }
  }
}
