import 'package:flutter/material.dart';
import 'package:personal_finance/service/auth_service.dart';

class Header extends StatelessWidget {
  const Header({super.key, required this.openDrawer});
  final VoidCallback openDrawer;

  @override
  Widget build(BuildContext context) {
    final user = AppAuthService.supabaseSession?.user;
    final displayName =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        user?.email ??
        '';
    final avatarUrl = user?.userMetadata?['avatar_url']?.toString();

    return Row(
      children: [
        InkWell(
          onTap: openDrawer,
          child: CircleAvatar(
            backgroundImage: NetworkImage(avatarUrl ?? ''),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(text: '👋 Xin chào, '),
                      TextSpan(
                        text: displayName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Chào mừng đến với FinMan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(onPressed: () {}, icon: Icon(Icons.notifications_none)),
      ],
    );
  }
}
