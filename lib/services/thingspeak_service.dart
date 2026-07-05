import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cat-detection trigger distance, in cm — must match `distanceThreshold` in
/// the firmware. Used here to translate raw proximity readings ("distance")
/// into a human "is the pet at the feeder right now" signal.
const int kDetectionThresholdCm = 15;

/// One reading from the feeder's ThingSpeak channel.
class ThingSpeakPoint {
  final DateTime time;
  final double? distance; // field1 — proximity of the pet to the feeder, not food level
  final double? feedCount; // field2 — cumulative count since the device was first set up
  final double? detectionCount; // field3 — cumulative visit count since setup

  ThingSpeakPoint({required this.time, this.distance, this.feedCount, this.detectionCount});
}

/// Derived, human-meaningful stats computed from a window of raw
/// [ThingSpeakPoint]s — totals, session deltas, visit pacing, and a
/// day-by-day breakdown — instead of just plotting the raw counters.
class ThingSpeakInsights {
  final int totalFeeds;
  final int totalVisits;
  final int feedsInWindow;
  final int visitsInWindow;
  final Duration windowSpan;
  final double? avgMinutesBetweenVisits;
  final bool currentlyNear;
  final double? latestDistance;
  final Map<DateTime, int> dailyFeeds;
  final Map<DateTime, int> dailyVisits;

  ThingSpeakInsights({
    required this.totalFeeds,
    required this.totalVisits,
    required this.feedsInWindow,
    required this.visitsInWindow,
    required this.windowSpan,
    required this.avgMinutesBetweenVisits,
    required this.currentlyNear,
    required this.latestDistance,
    required this.dailyFeeds,
    required this.dailyVisits,
  });

  static ThingSpeakInsights empty() => ThingSpeakInsights(
        totalFeeds: 0,
        totalVisits: 0,
        feedsInWindow: 0,
        visitsInWindow: 0,
        windowSpan: Duration.zero,
        avgMinutesBetweenVisits: null,
        currentlyNear: false,
        latestDistance: null,
        dailyFeeds: {},
        dailyVisits: {},
      );

  factory ThingSpeakInsights.compute(List<ThingSpeakPoint> points, {int detectionThresholdCm = kDetectionThresholdCm}) {
    if (points.isEmpty) return ThingSpeakInsights.empty();

    double? firstFeed, firstVisit, lastFeed, lastVisit;
    for (final p in points) {
      firstFeed ??= p.feedCount;
      firstVisit ??= p.detectionCount;
    }
    for (final p in points.reversed) {
      lastFeed ??= p.feedCount;
      lastVisit ??= p.detectionCount;
    }

    final totalFeeds = (lastFeed ?? 0).round();
    final totalVisits = (lastVisit ?? 0).round();
    final feedsInWindow = ((lastFeed ?? 0) - (firstFeed ?? 0)).round().clamp(0, 1 << 30);
    final visitsInWindow = ((lastVisit ?? 0) - (firstVisit ?? 0)).round().clamp(0, 1 << 30);
    final windowSpan = points.last.time.difference(points.first.time);
    final avgMinutesBetweenVisits = visitsInWindow > 0 && windowSpan.inMinutes > 0
        ? windowSpan.inMinutes / visitsInWindow
        : null;

    final latestDistance = points.last.distance;
    final currentlyNear = latestDistance != null && latestDistance > 0 && latestDistance < detectionThresholdCm;

    return ThingSpeakInsights(
      totalFeeds: totalFeeds,
      totalVisits: totalVisits,
      feedsInWindow: feedsInWindow,
      visitsInWindow: visitsInWindow,
      windowSpan: windowSpan,
      avgMinutesBetweenVisits: avgMinutesBetweenVisits,
      currentlyNear: currentlyNear,
      latestDistance: latestDistance,
      dailyFeeds: _dailyDelta(points, (p) => p.feedCount),
      dailyVisits: _dailyDelta(points, (p) => p.detectionCount),
    );
  }

  /// Buckets a cumulative counter by local calendar day and returns each
  /// day's increase (last reading of the day minus its first) — turning a
  /// running total into a "how many happened on this day" number.
  static Map<DateTime, int> _dailyDelta(List<ThingSpeakPoint> points, double? Function(ThingSpeakPoint) selector) {
    final Map<DateTime, List<double>> byDay = {};
    for (final p in points) {
      final v = selector(p);
      if (v == null) continue;
      final local = p.time.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDay.putIfAbsent(day, () => []).add(v);
    }
    final result = <DateTime, int>{};
    for (final entry in byDay.entries) {
      result[entry.key] = (entry.value.last - entry.value.first).round().clamp(0, 1 << 30);
    }
    return result;
  }
}

/// Reads (never writes) the feeder's ThingSpeak channel via its JSON API, so
/// the app can render its own native charts instead of embedding the
/// ThingSpeak website. Read-only key — safe to keep here, it can't write to
/// the channel or affect the feeder.
class ThingSpeakService {
  static const String _channelId = "3421598";
  static const String _readApiKey = "Q0OCEU22EC8PLNNS";

  /// Fetches the most recent [results] readings, oldest first (matching how
  /// ThingSpeak returns them), ready to plot directly on a chart's x-axis.
  static Future<List<ThingSpeakPoint>?> fetchRecent({int results = 30}) async {
    try {
      final uri = Uri.parse(
        "https://api.thingspeak.com/channels/$_channelId/feeds.json?api_key=$_readApiKey&results=$results",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final feeds = (body['feeds'] as List?) ?? const [];

      return feeds.map((f) {
        final map = f as Map<String, dynamic>;
        return ThingSpeakPoint(
          time: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
          distance: double.tryParse(map['field1']?.toString() ?? ''),
          feedCount: double.tryParse(map['field2']?.toString() ?? ''),
          detectionCount: double.tryParse(map['field3']?.toString() ?? ''),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
