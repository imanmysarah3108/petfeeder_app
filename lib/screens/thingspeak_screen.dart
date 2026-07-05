import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/thingspeak_service.dart';
import '../theme/app_theme.dart';

/// Native charts built from the feeder's ThingSpeak channel data, styled to
/// match the rest of the app — instead of embedding the ThingSpeak website
/// in a WebView.
class ThingSpeakScreen extends StatefulWidget {
  const ThingSpeakScreen({super.key});

  @override
  State<ThingSpeakScreen> createState() => _ThingSpeakScreenState();
}

class _ThingSpeakScreenState extends State<ThingSpeakScreen> {
  List<ThingSpeakPoint>? _points;
  bool _loading = true;
  bool _failed = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    // The feeder itself only reports every ~16s, so refreshing much faster
    // than that wouldn't show anything new.
    _autoRefresh = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    // Wider window than the home screen's mini preview — enough to compute
    // session/day-level insights, not just draw a line.
    final fetched = await ThingSpeakService.fetchRecent(results: 200);
    if (!mounted) return;
    if (fetched == null) {
      setState(() {
        _loading = false;
        _failed = _points == null; // only show a hard error if we have nothing to show at all
      });
    } else {
      setState(() {
        _points = fetched;
        _loading = false;
        _failed = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return "${d.inDays}d ${d.inHours % 24}h";
    if (d.inHours >= 1) return "${d.inHours}h ${d.inMinutes % 60}m";
    if (d.inMinutes >= 1) return "${d.inMinutes}m";
    return "<1m";
  }

  String _dayLabel(DateTime day) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
    return isToday ? "Today" : weekdays[day.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_back, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Cloud analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _failed
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "Couldn't load ThingSpeak data — check your internet connection, then pull down to retry.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _load(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    "Live data from the feeder's ThingSpeak channel, reported roughly every 16 seconds.",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  if (_points == null && _loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Builder(builder: (context) {
                      final insights = ThingSpeakInsights.compute(_points!);
                      return _InsightsSection(insights: insights, formatDuration: _formatDuration);
                    }),
                    const SizedBox(height: 28),

                    const Text(
                      "ACTIVITY BY DAY",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      // Recomputed here rather than threading a single instance down —
                      // the input list is small (<=200 points) so this stays cheap.
                      final insights = ThingSpeakInsights.compute(_points!);
                      if (insights.dailyFeeds.length <= 1 && insights.dailyVisits.length <= 1) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "Not enough days of data yet for a day-by-day breakdown — check back once the feeder's been reporting for more than a day.",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          _BarCard(
                            title: "Feeds per day",
                            color: const Color(0xFF4CAF50),
                            data: insights.dailyFeeds,
                            dayLabel: _dayLabel,
                          ),
                          const SizedBox(height: 20),
                          _BarCard(
                            title: "Visits per day",
                            color: const Color(0xFFB05B00),
                            data: insights.dailyVisits,
                            dayLabel: _dayLabel,
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 28),
                    const Text(
                      "RAW READINGS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: "Proximity to feeder (cm)",
                      color: AppTheme.primaryColor,
                      values: _points!.map((p) => p.distance ?? 0).toList(),
                    ),
                    const SizedBox(height: 20),
                    _ChartCard(
                      title: "Cumulative feeds",
                      color: const Color(0xFF4CAF50),
                      values: _points!.map((p) => p.feedCount ?? 0).toList(),
                    ),
                    const SizedBox(height: 20),
                    _ChartCard(
                      title: "Cumulative visits",
                      color: const Color(0xFFB05B00),
                      values: _points!.map((p) => p.detectionCount ?? 0).toList(),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<double> values;

  const _ChartCard({required this.title, required this.color, required this.values});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final latest = values.isEmpty ? 0 : values.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                latest.toStringAsFixed(latest == latest.roundToDouble() ? 0 : 1),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: spots.isEmpty
                ? Center(
                    child: Text("No data yet", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Turns the raw cumulative counters into a handful of plain-English stats:
/// totals, how much happened in the fetched window, and how often the pet
/// has been visiting — instead of making the reader eyeball a line chart.
class _InsightsSection extends StatelessWidget {
  final ThingSpeakInsights insights;
  final String Function(Duration) formatDuration;

  const _InsightsSection({required this.insights, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insights.latestDistance != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: insights.currentlyNear ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  insights.currentlyNear ? Icons.pets : Icons.pets_outlined,
                  size: 18,
                  color: insights.currentlyNear ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insights.currentlyNear
                        ? "Pet is at the feeder right now (${insights.latestDistance!.toStringAsFixed(0)} cm)"
                        : "No pet at the feeder right now (last reading: ${insights.latestDistance!.toStringAsFixed(0)} cm)",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: insights.currentlyNear ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(child: _StatTile(label: "Total feeds", value: "${insights.totalFeeds}", icon: Icons.restaurant)),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: "Total visits", value: "${insights.totalVisits}", icon: Icons.pets)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: "In this window",
                value: "${insights.feedsInWindow} feeds",
                icon: Icons.schedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: "Avg. gap between visits",
                value: insights.avgMinutesBetweenVisits != null
                    ? "${insights.avgMinutesBetweenVisits!.toStringAsFixed(0)} min"
                    : "Not enough data",
                icon: Icons.timelapse,
              ),
            ),
          ],
        ),
        if (insights.windowSpan > Duration.zero) ...[
          const SizedBox(height: 12),
          Text(
            "Based on ${insights.feedsInWindow} feed(s) and ${insights.visitsInWindow} visit(s) "
            "over the last ${formatDuration(insights.windowSpan)} of reported data.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// A per-day bar chart built from a cumulative counter's daily deltas (see
/// [ThingSpeakInsights.dailyFeeds]/[dailyVisits]) — "how many happened on
/// this day" instead of a running total.
class _BarCard extends StatelessWidget {
  final String title;
  final Color color;
  final Map<DateTime, int> data;
  final String Function(DateTime) dayLabel;

  const _BarCard({required this.title, required this.color, required this.data, required this.dayLabel});

  @override
  Widget build(BuildContext context) {
    final days = data.keys.toList()..sort();
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: (maxValue * 1.25).clamp(1, double.infinity),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(dayLabel(days[i]), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (data[days[i]] ?? 0).toDouble(),
                          color: color,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
