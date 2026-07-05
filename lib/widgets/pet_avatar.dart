import 'dart:io';
import 'package:flutter/material.dart';

/// Bundled preset avatars — a color + the paw icon, since we don't ship
/// separate artwork per species. Kept simple on purpose: differentiate by
/// color and label rather than needing a distinct icon per animal.
const Map<String, Color> kPetPresetColors = {
  'dog': Color(0xFFD66B1E),
  'cat': Color(0xFF6B7FD6),
  'rabbit': Color(0xFFD6608D),
  'bird': Color(0xFF3FA796),
  'hamster': Color(0xFFB08B2F),
};

const List<String> kPetPresetIds = ['dog', 'cat', 'rabbit', 'bird', 'hamster'];

// Distinct emoji per species. Previously every preset rendered the same
// Icons.pets glyph and differed only by a faint background tint, which read
// as "all the same avatar" at a glance — emoji give each one a genuinely
// different shape, not just a different color.
const Map<String, String> kPetPresetEmojis = {
  'dog': '🐶',
  'cat': '🐱',
  'rabbit': '🐰',
  'bird': '🐦',
  'hamster': '🐹',
};

/// Renders whatever the pet's photo reference points to: a bundled preset
/// ("preset:<id>") or a real photo picked from camera/gallery
/// ("file:<absolute path>"). Falls back to the dog preset if the reference
/// is missing/invalid or the file no longer exists.
class PetAvatar extends StatelessWidget {
  final String photoRef;
  final double radius;

  const PetAvatar({super.key, required this.photoRef, this.radius = 45});

  @override
  Widget build(BuildContext context) {
    if (photoRef.startsWith('file:')) {
      final path = photoRef.substring(5);
      final file = File(path);
      if (file.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      }
    }

    final id = photoRef.startsWith('preset:') ? photoRef.substring(7) : 'dog';
    final color = kPetPresetColors[id] ?? kPetPresetColors['dog']!;
    final emoji = kPetPresetEmojis[id] ?? kPetPresetEmojis['dog']!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(emoji, style: TextStyle(fontSize: radius)),
    );
  }
}
