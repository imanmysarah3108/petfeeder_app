import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/feeding_alarm.dart';
import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/inline_status.dart';

/// True alarm-clock style feeding schedule — any number of saved times can
/// be enabled at once, each firing independently on its own hour:minute.
/// Every action reports its own inline loading/success/error right on the
/// row it affects, instead of a SnackBar popping up after the fact.
class FeedingAlarmsScreen extends StatefulWidget {
  const FeedingAlarmsScreen({super.key});

  @override
  State<FeedingAlarmsScreen> createState() => _FeedingAlarmsScreenState();
}

class _FeedingAlarmsScreenState extends State<FeedingAlarmsScreen> {
  ActionStatus _buzzerStatus = ActionStatus.idle;
  ActionStatus _addStatus = ActionStatus.idle;
  String _addError = "";

  // Per-alarm inline status, keyed by alarm id — lets each row show its own
  // loading/success/error independent of the others.
  final Map<String, ActionStatus> _rowStatus = {};
  final Map<String, String> _rowError = {};

  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loadingList = true);
    await context.read<FeedingProvider>().refreshAlarms();
    if (!mounted) return;
    setState(() => _loadingList = false);
  }

  void _setRowStatus(String id, ActionStatus status, {String error = ""}) {
    if (!mounted) return;
    setState(() {
      _rowStatus[id] = status;
      _rowError[id] = error;
    });
    if (status == ActionStatus.success || status == ActionStatus.error) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _rowStatus[id] = ActionStatus.idle);
      });
    }
  }

  Future<void> _addAlarm() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _addStatus = ActionStatus.loading;
      _addError = "";
    });
    final result = await context.read<FeedingProvider>().addAlarm(picked);
    if (!mounted) return;
    setState(() {
      _addStatus = result.ok ? ActionStatus.success : ActionStatus.error;
      _addError = result.message;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _addStatus = ActionStatus.idle);
    });
  }

  Future<void> _toggleAlarm(FeedingAlarm alarm, bool value) async {
    _setRowStatus(alarm.id, ActionStatus.loading);
    final result = await context.read<FeedingProvider>().setAlarmEnabled(alarm.id, value);
    if (!mounted) return;
    _setRowStatus(alarm.id, result.ok ? ActionStatus.success : ActionStatus.error, error: result.message);
  }

  Future<void> _deleteAlarm(FeedingAlarm alarm) async {
    _setRowStatus(alarm.id, ActionStatus.loading);
    final result = await context.read<FeedingProvider>().deleteAlarm(alarm.id);
    if (!mounted) return;
    if (!result.ok) {
      _setRowStatus(alarm.id, ActionStatus.error, error: result.message);
    }
    // On success the row simply disappears (list refreshes from the
    // device's response), so there's no row left to flip to "success".
  }

  Future<void> _toggleBuzzer(bool value) async {
    setState(() => _buzzerStatus = ActionStatus.loading);
    final ok = await context.read<FeedingProvider>().updateBuzzer(value);
    if (!mounted) return;
    setState(() => _buzzerStatus = ok ? ActionStatus.success : ActionStatus.error);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _buzzerStatus = ActionStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();

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
        title: const Text("Feeding schedule", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _loadingList
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loadingList ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _addAlarm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.notifications_none, color: Colors.grey.shade700),
              title: const Text("Feeding buzzer", style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text(
                "Sounds a 5s alert whenever a scheduled feeding time dispenses",
                style: TextStyle(fontSize: 12),
              ),
              value: provider.buzzerEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: _toggleBuzzer,
            ),
          ),
          InlineStatusBanner(
            status: _buzzerStatus,
            loadingText: "Updating buzzer...",
            successText: "Buzzer updated",
            errorText: "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again",
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.alarms.isEmpty ? "No feeding times set yet" : "Saved feeding times",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
              ),
              Text(
                "Any number can be on at once",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 12),

          InlineStatusBanner(
            status: _addStatus,
            loadingText: "Adding feeding time...",
            successText: "Feeding time added",
            errorText: _addError.isNotEmpty
                ? _addError
                : "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again",
            margin: const EdgeInsets.only(bottom: 12),
          ),

          if (provider.alarms.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.alarm_add, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    "Add a feeding time",
                    style: TextStyle(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tap + to save a time. Any number of feeding times can be switched on at once.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...provider.alarms.map((alarm) {
              final rowStatus = _rowStatus[alarm.id] ?? ActionStatus.idle;
              final rowError = _rowError[alarm.id] ?? "";
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: alarm.enabled ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                alarm.displayTime,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: alarm.enabled ? AppTheme.darkPrimary : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                alarm.enabled ? "On" : "Off",
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        InlineStatusDot(status: rowStatus),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
                          onPressed: rowStatus == ActionStatus.loading ? null : () => _deleteAlarm(alarm),
                        ),
                        Switch(
                          value: alarm.enabled,
                          activeColor: AppTheme.primaryColor,
                          onChanged: rowStatus == ActionStatus.loading ? null : (v) => _toggleAlarm(alarm, v),
                        ),
                      ],
                    ),
                    if (rowStatus == ActionStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            rowError.isNotEmpty
                                ? rowError
                                : "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again",
                            style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
