import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthService {
  AppAuthService._();

  static final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String? get supabaseUserId => _supabase.auth.currentUser?.id;

  static String? get firebaseUserId => _firebaseAuth.currentUser?.uid;

  static firebase_auth.User? get firebaseUser => _firebaseAuth.currentUser;

  static Session? get supabaseSession => _supabase.auth.currentSession;

  static Stream<Session?> supabaseSessionChanges() {
    return _supabase.auth.onAuthStateChange.map((event) => event.session);
  }

  static Future<bool> signInWithGoogle() async {
    final scopes = <String>[
      'email',
      'https://www.googleapis.com/auth/spreadsheets',
    ];

    try {
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError('Google token missing');
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      try {
        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      } catch (firebaseError) {
        debugPrint(
          'Firebase sign-in failed but Supabase succeeded: $firebaseError',
        );
      }
      return true;
    } catch (e, s) {
      debugPrint('AppAuthService signInWithGoogle error: $e');
      debugPrint(s.toString());
      return false;
    }
  }

  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error: $e');
    }

    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('Google disconnect error: $e');
    }

    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Firebase signOut error: $e');
    }
  }
}
