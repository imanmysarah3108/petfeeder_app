/// A saved feeding time in the app's alarm list. True multiple alarms, like
/// a phone's alarm clock — any number can be [enabled] at once, each firing
/// independently on its own time. [id] mirrors the device's own id for this
/// alarm ("HHMM"), since the ESP32 is the source of truth for the list.
class FeedingAlarm {
  final String id;
  final int hour; // 24-hour format
  final int minute;
  final bool enabled;

  FeedingAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.enabled = false,
  });

  FeedingAlarm copyWith({int? hour, int? minute, bool? enabled}) {
    return FeedingAlarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  String get displayTime {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12raw = hour % 12;
    final h12 = h12raw == 0 ? 12 : h12raw;
    return "${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period";
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      };

  factory FeedingAlarm.fromJson(Map<String, dynamic> json) => FeedingAlarm(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        enabled: json['enabled'] as bool? ?? false,
      );
}
