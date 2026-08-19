import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/avatar_catalog.dart';
import 'person_avatar_painter.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.avatarId, this.radius = 28});

  final String? avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final option = avatarById(avatarId);
    if (option == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.mint,
        child: Icon(
          Icons.person_rounded,
          color: AppColors.primary,
          size: radius,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: option.background,
      child: SizedBox(
        width: radius * 1.7,
        height: radius * 1.7,
        child: CustomPaint(
          painter: PersonAvatarPainter(option.spec),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
