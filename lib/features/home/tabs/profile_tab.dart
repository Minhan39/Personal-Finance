import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/theme/theme_bloc.dart';
import '../../../blocs/theme/theme_event.dart';
import '../../../blocs/theme/theme_state.dart';
import '../../../service/auth_service.dart';
import '../../../shared/ui/ui.dart';
import 'overview_tab.dart';

/// Account info, appearance settings and sign-out (replaces the old drawer).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  static const _colorNames = {
    AppThemeColor.green: 'Xanh lục',
    AppThemeColor.blue: 'Xanh dương',
    AppThemeColor.purple: 'Tím',
  };

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AppAuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = context.watch<ThemeBloc>().state;
    final user = AppAuthService.supabaseSession?.user;
    final name =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        '';

    return ModuleScaffold(
      title: 'Tài khoản',
      showBack: false,
      children: [
        AppCard(
          child: Row(
            children: [
              const UserAvatar(radius: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      user?.email ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Chế độ giao diện'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Hệ thống'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Sáng'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Tối'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {themeState.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => context
                      .read<ThemeBloc>()
                      .add(ChangeThemeMode(selection.first)),
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Màu chủ đạo'),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final color in AppThemeColor.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _ColorOption(
                        color: ThemeState(
                          mode: themeState.mode,
                          color: color,
                        ).getColorPrimary,
                        label: _colorNames[color]!,
                        selected: themeState.color == color,
                        onTap: () => context.read<ThemeBloc>().add(
                          ChangeThemeColor(color),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          onTap: () => _signOut(context),
          child: ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Đăng xuất',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
