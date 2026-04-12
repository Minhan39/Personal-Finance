import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<UserCredential?> _signInWithGoogle() async {
    final List<String> scopes = [
      'email',
      'https://www.googleapis.com/auth/spreadsheets',
    ];

    try {
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate(scopeHint: scopes);

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e, s) {
      debugPrint('Google sign-in error: $e');
      debugPrint(s.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Đăng nhập bằng Google'),
          onPressed: () async {
            final user = await _signInWithGoogle();
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đăng nhập thất bại')),
              );
            }
          },
        ),
      ),
    );
  }
}
