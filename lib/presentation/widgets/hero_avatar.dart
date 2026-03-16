import 'package:flutter/material.dart';
import 'package:rov_coach/data/hero_database.dart';

/// A reusable widget that displays a hero's portrait image with a robust
/// fallback when the asset is missing.
///
/// Use [HeroAvatar.fromName] when you only have the hero name string.
class HeroAvatar extends StatelessWidget {
  final String heroName;
  final String imagePath;
  final String? mainRole;
  final double size;
  final BoxShape shape;

  const HeroAvatar({
    super.key,
    required this.heroName,
    required this.imagePath,
    this.mainRole,
    this.size = 40,
    this.shape = BoxShape.circle,
  });

  /// Convenience constructor that looks up the hero by name in [RoVDatabase].
  factory HeroAvatar.fromName(
    String heroName, {
    Key? key,
    double size = 40,
    BoxShape shape = BoxShape.circle,
  }) {
    final hero = RoVDatabase.findByName(heroName);
    return HeroAvatar(
      key: key,
      heroName: heroName,
      imagePath: hero?.imagePath ?? '',
      mainRole: hero?.mainRole,
      size: size,
      shape: shape,
    );
  }

  Color _roleColor() {
    switch (mainRole) {
      case 'Slayer':
        return Colors.red.shade700;
      case 'Jungle':
        return Colors.green.shade700;
      case 'Mid':
        return Colors.purple.shade700;
      case 'Dragon':
        return Colors.orange.shade700;
      case 'Support':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath.isEmpty) {
      return _fallback();
    }

    final borderRadius =
        shape == BoxShape.circle ? BorderRadius.circular(size) : BorderRadius.circular(6);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final color = _roleColor();
    final letter = heroName.isNotEmpty ? heroName[0].toUpperCase() : '?';

    if (shape == BoxShape.circle) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: color.withAlpha(50),
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
