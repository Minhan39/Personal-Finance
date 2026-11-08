import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:personal_finance/service/auth_service.dart';

import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _signOut() async {
    await AppAuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeBloc>().state;
    final user = AppAuthService.supabaseSession?.user;
    final avatarUrl = user?.userMetadata?['avatar_url']?.toString();
    final displayName =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        user?.email ??
        '';

    return SafeArea(
      child: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl ?? ''),
              ),
              accountName: Text(displayName),
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
