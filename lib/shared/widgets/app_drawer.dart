import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _signOut() async {
    await GoogleSignIn.instance.disconnect();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeBloc>().state;
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(user?.photoURL ?? ''),
              ),
              accountName: Text(user?.displayName ?? ''),
              accountEmail: Text(user?.email ?? ''),
            ),
            const ListTile(title: Text("Chế độ giao diện")),
            RadioListTile<ThemeMode>(
              title: const Text('Hệ thống'),
              value: ThemeMode.system,
              groupValue: themeState.mode,
              onChanged: (mode) =>
                  context.read<ThemeBloc>().add(ChangeThemeMode(mode!)),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Sáng'),
              value: ThemeMode.light,
              groupValue: themeState.mode,
              onChanged: (mode) =>
                  context.read<ThemeBloc>().add(ChangeThemeMode(mode!)),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Tối'),
              value: ThemeMode.dark,
              groupValue: themeState.mode,
              onChanged: (mode) =>
                  context.read<ThemeBloc>().add(ChangeThemeMode(mode!)),
            ),
            const Divider(),
            const ListTile(title: Text("Chế độ màu sắc")),
            RadioListTile<AppThemeColor>(
              title: const Text('Xanh lục'),
              value: AppThemeColor.green,
              groupValue: themeState.color,
              onChanged: (color) =>
                  context.read<ThemeBloc>().add(ChangeThemeColor(color!)),
            ),
            RadioListTile<AppThemeColor>(
              title: const Text('Xanh dương'),
              value: AppThemeColor.blue,
              groupValue: themeState.color,
              onChanged: (color) =>
                  context.read<ThemeBloc>().add(ChangeThemeColor(color!)),
            ),
            RadioListTile<AppThemeColor>(
              title: const Text('Tím than'),
              value: AppThemeColor.purple,
              groupValue: themeState.color,
              onChanged: (color) =>
                  context.read<ThemeBloc>().add(ChangeThemeColor(color!)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () => _signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
