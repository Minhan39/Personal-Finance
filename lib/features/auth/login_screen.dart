import 'package:flutter/material.dart';
import 'package:personal_finance/service/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Đăng nhập bằng Google'),
          onPressed: () async {
            final success = await AppAuthService.signInWithGoogle();
            if (!context.mounted) {
              return;
            }
            if (!success) {
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
