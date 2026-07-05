import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../screens/thingspeak_screen.dart';
import '../services/thingspeak_service.dart';
import '../theme/app_theme.dart';

/// Small dashboard preview of the feeder's ThingSpeak distance readings —
/// one of the cloud analytics graphs, surfaced right on the home screen
/// instead of only living behind Settings. Tapping it opens the full
/// Cloud Analytics page. The "pet at feeder now" status line uses
/// [kDetectionThresholdCm] from thingspeak_service.dart, kept in sync with
/// the firmware's own `distanceThreshold`.
class DistanceTrendCard extends StatefulWidget {
  const DistanceTrendCard({super.key});

  @override
  State<DistanceTrendCard> createState() => _DistanceTrendCardState();
}

class _DistanceTrendCardState extends State<DistanceTrendCard> {
  List<double>? _values;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final fetched = await ThingSpeakService.fetchRecent(results: 15);
    if (!mounted) return;
    setState(() {
      if (fetched == null) {
        _failed = _values == null;
      } else {
        _values = fetched.map((p) => p.distance ?? 0).toList();
        _failed = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThingSpeakScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_outlined, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    const Text("Proximity trend", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
              ],
            ),
            if (_values != null && _values!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Builder(builder: (context) {
                  final latest = _values!.last;
                  final near = latest > 0 && latest < kDetectionThresholdCm;
                  return Row(
                    children: [
                      Icon(
                        near ? Icons.pets : Icons.pets_outlined,
                        size: 12,
                        color: near ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        near ? "Pet at feeder now" : "No pet detected (${latest.toStringAsFixed(0)} cm)",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: near ? const Color(0xFF4CAF50) : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: _failed
                  ? Center(
                      child: Text(
                        "Couldn't load cloud data",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    )
                  : (_values == null || _values!.isEmpty)
                      ? Center(
                          child: Text("No data yet", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (int i = 0; i < _values!.length; i++) FlSpot(i.toDouble(), _values![i]),
                                ],
                                isCurved: true,
                                color: AppTheme.primaryColor,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
