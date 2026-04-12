import 'package:flutter/material.dart';

enum SaveCardType { primary, contrast }

class SaveCard extends StatelessWidget {
  const SaveCard({super.key, required this.type, required this.title, required this.image, required this.value, required this.onPressed});
  final SaveCardType type;
  final String title;
  final String image;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: type == SaveCardType.primary
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.transparent,
                backgroundImage: NetworkImage(image),
              ),
            ),
            Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.surface,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
