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
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? null
                    : const Icon(Icons.person),
              ),
              accountName: Text(displayName),
              accountEmail: Text(user?.email ?? ''),
            ),
            const ListTile(title: Text("Chế độ giao diện")),
            RadioGroup<ThemeMode>(
              groupValue: themeState.mode,
              onChanged: (mode) {
                if (mode != null) {
                  context.read<ThemeBloc>().add(ChangeThemeMode(mode));
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Hệ thống'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Sáng'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Tối'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
            const Divider(),
            const ListTile(title: Text("Chế độ màu sắc")),
            RadioGroup<AppThemeColor>(
              groupValue: themeState.color,
              onChanged: (color) {
                if (color != null) {
                  context.read<ThemeBloc>().add(ChangeThemeColor(color));
                }
              },
              child: Column(
                children: [
                  RadioListTile<AppThemeColor>(
                    title: const Text('Xanh lục'),
                    value: AppThemeColor.green,
                  ),
                  RadioListTile<AppThemeColor>(
                    title: const Text('Xanh dương'),
                    value: AppThemeColor.blue,
                  ),
                  RadioListTile<AppThemeColor>(
                    title: const Text('Tím than'),
                    value: AppThemeColor.purple,
                  ),
                ],
              ),
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
