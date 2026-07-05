import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';
import '../widgets/dispense_button.dart';
import '../widgets/dispense_confirm_dialog.dart';
import '../widgets/distance_trend_card.dart';
import '../widgets/history_bottom_sheet.dart';
import '../widgets/inline_status.dart';
import '../widgets/pet_avatar.dart';
import 'settings_screen.dart';
import 'pet_profile_screen.dart';
import 'feeding_alarms_screen.dart';
import 'connection_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ActionStatus _buzzerStatus = ActionStatus.idle;

  String? _lastSeenDetection;
  bool _showDetectionBanner = false;
  Timer? _detectionTimer;

  // Captured once rather than re-fetched via context.read() inside
  // _onProviderChange — that callback is a raw ChangeNotifier listener, not
  // a widget lifecycle method, so it can in principle fire while this
  // widget is deactivated but not yet disposed, and looking up an inherited
  // widget via context during that window throws. See the same fix on
  // wifi_networks_screen.dart, where this exact pattern caused a crash.
  late final FeedingProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<FeedingProvider>();
    _lastSeenDetection = _provider.lastDetection;
    _provider.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChange);
    _detectionTimer?.cancel();
    super.dispose();
  }

  // A pet-detection event is a passive notification, not something the user
  // just tapped — so it gets a self-dismissing banner rather than either a
  // SnackBar or something that demands interaction.
  void _onProviderChange() {
    final detection = _provider.lastDetection;
    // Skip the firmware's "Never" placeholder (no detection has happened
    // yet) so a fresh app/device boot doesn't show a fake banner.
    if (detection.isNotEmpty && detection != "Never" && detection != _lastSeenDetection) {
      _lastSeenDetection = detection;
      _detectionTimer?.cancel();
      setState(() => _showDetectionBanner = true);
      // A silent banner is easy to miss if the phone isn't being looked at
      // right when it appears — a buzz gives it a physical nudge too,
      // matching the feeder's own new detection chirp (see firmware's
      // detectionChirp()).
      HapticFeedback.mediumImpact();
      _detectionTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showDetectionBanner = false);
      });
    }
  }

  void _openConnectionDetails(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionDetailsScreen()));
  }

  void _openPetProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PetProfileScreen()));
  }

  void _openAlarms(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedingAlarmsScreen()));
  }

  void _openHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HistoryBottomSheet(),
    );
  }

  void _dispense(BuildContext context) {
    showDialog(context: context, builder: (_) => const DispenseConfirmDialog());
  }

  Future<void> _toggleBuzzer(bool v) async {
    setState(() => _buzzerStatus = ActionStatus.loading);
    final ok = await context.read<FeedingProvider>().updateBuzzer(v);
    if (!mounted) return;
    setState(() => _buzzerStatus = ok ? ActionStatus.success : ActionStatus.error);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _buzzerStatus = ActionStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();
    final reachable = provider.deviceReachable;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pets, color: AppTheme.darkPrimary, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        "Pet feeder",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: AppTheme.darkPrimary),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),

              // Pet-detection banner — self-dismissing, appears above
              // everything else when the sensor sees the pet at the feeder.
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _showDetectionBanner
                    ? Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text("🐾", style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Pet detected at the feeder (${provider.lastDetection})",
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFFB05B00)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),

              const SizedBox(height: 14),

              // Merged connection status — tap for details
              GestureDetector(
                onTap: () => _openConnectionDetails(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: reachable ? const Color(0xFFE8F5E9) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: reachable ? const Color(0xFF4CAF50) : Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reachable ? "Feeder online" : "Can't reach feeder",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: reachable ? const Color(0xFF2E7D32) : Colors.red.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        provider.deviceHost,
                        style: TextStyle(
                          fontSize: 12,
                          color: reachable ? const Color(0xFF5F8A63) : Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: reachable ? const Color(0xFF5F8A63) : Colors.red.shade400),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Pet identity — tap the avatar to open the profile page
              GestureDetector(
                onTap: () => _openPetProfile(context),
                child: Row(
                  children: [
                    PetAvatar(photoRef: provider.petPhoto, radius: 26),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.petName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkPrimary),
                        ),
                        Text(
                          "${provider.breed}, ${provider.weight}kg",
                          style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Feeding stat tiles
              Row(
                children: [
                  Expanded(child: _StatTile(label: "Last fed", value: provider.lastFeed)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(label: "Next feed", value: provider.nextFeed)),
                ],
              ),

              const SizedBox(height: 10),

              // Cloud analytics preview — tap through to the full Cloud
              // Analytics page under Settings.
              const DistanceTrendCard(),

              const SizedBox(height: 10),

              // Buzzer — direct toggle, inline result instead of a SnackBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_none, size: 18, color: AppTheme.darkPrimary),
                        const SizedBox(width: 10),
                        const Text("Feeding schedule buzzer", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        InlineStatusDot(status: _buzzerStatus),
                        const SizedBox(width: 4),
                        Switch(
                          value: provider.buzzerEnabled,
                          activeColor: AppTheme.primaryColor,
                          onChanged: _toggleBuzzer,
                        ),
                      ],
                    ),
                    if (_buzzerStatus == ActionStatus.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Couldn't reach the feeder — check Wi-Fi and try again",
                            style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Dispense button
              Center(child: DispenseButton(onPressed: () => _dispense(context))),

              const SizedBox(height: 28),

              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      icon: Icons.schedule,
                      title: "Schedule",
                      iconColor: AppTheme.primaryColor,
                      iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      onTap: () => _openAlarms(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ActionCard(
                      icon: Icons.history,
                      title: "History",
                      iconColor: AppTheme.primaryColor,
                      iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      onTap: () => _openHistory(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Recent activity preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent activity", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: () => _openHistory(context),
                    child: Text("View all", style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (provider.history.isEmpty)
                Text("No activity yet", style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
              else
                ...provider.history.take(3).map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 16,
                          color: item.success ? const Color(0xFF4CAF50) : Colors.red.shade400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(item.time, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (item.amount != null)
                          Text(
                            "${item.amount}g",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                          ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        ],
      ),
    );
  }
}
