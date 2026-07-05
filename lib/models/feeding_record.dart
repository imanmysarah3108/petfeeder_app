import 'package:flutter/material.dart';

// Every icon FeedingRecord/the activity log ever uses, keyed by a stable
// string name for persistence. Flutter's release-build icon tree-shaker
// requires every IconData to be a compile-time constant so it can work out
// which glyphs to keep — building one from an arbitrary runtime int (as
// this used to do when restoring from storage) breaks `flutter build apk`
// with "non-constant invocations of IconData". Looking a saved key up in
// this fixed const map instead always yields one of these real Icons.*
// constants, so tree-shaking still works.
const Map<String, IconData> _kIconRegistry = {
  'restaurant': Icons.restaurant,
  'info_outline': Icons.info_outline,
  'wifi': Icons.wifi,
  'wifi_off': Icons.wifi_off,
  'notifications_none': Icons.notifications_none,
  'alarm_add': Icons.alarm_add,
  'delete_outline': Icons.delete_outline,
  'alarm': Icons.alarm,
  'alarm_off': Icons.alarm_off,
  'pets': Icons.pets,
};

const String _kDefaultIconKey = 'restaurant';

/// A single entry in the app's combined activity log — covers actual
/// dispenses (amount != null) as well as other interactions like schedule
/// or buzzer changes (amount is null, success/failure shown instead).
class FeedingRecord {
  final String title;
  final String time;
  final int? amount;
  final bool success;
  final IconData icon;

  FeedingRecord({
    required this.title,
    required this.time,
    this.amount,
    this.success = true,
    this.icon = Icons.restaurant,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'time': time,
        'amount': amount,
        'success': success,
        'icon': _kIconRegistry.entries
            .firstWhere((e) => e.value.codePoint == icon.codePoint, orElse: () => const MapEntry(_kDefaultIconKey, Icons.restaurant))
            .key,
      };

  factory FeedingRecord.fromJson(Map<String, dynamic> json) => FeedingRecord(
        title: json['title']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
        amount: json['amount'] as int?,
        success: json['success'] == true,
        icon: _kIconRegistry[json['icon']?.toString()] ?? Icons.restaurant,
      );
}
