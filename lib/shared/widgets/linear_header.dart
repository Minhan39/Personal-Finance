import 'package:flutter/material.dart';

class LinearHeader extends StatelessWidget {
  const LinearHeader({super.key, required this.child, this.height});
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Theme.of(context).primaryColor.withValues(alpha: 0.5),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: child,
    );
  }
}
