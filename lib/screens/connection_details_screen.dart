import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/inline_status.dart';
import 'wifi_networks_screen.dart';

class ConnectionDetailsScreen extends StatefulWidget {
  const ConnectionDetailsScreen({super.key});

  @override
  State<ConnectionDetailsScreen> createState() => _ConnectionDetailsScreenState();
}

class _ConnectionDetailsScreenState extends State<ConnectionDetailsScreen> {
  late TextEditingController hostController;
  bool _retrying = false;

  ActionStatus _hostStatus = ActionStatus.idle;

  @override
  void initState() {
    super.initState();
    hostController = TextEditingController(text: context.read<FeedingProvider>().deviceHost);
  }

  @override
  void dispose() {
    hostController.dispose();
    super.dispose();
  }

  Future<void> _retry(FeedingProvider provider) async {
    setState(() => _retrying = true);
    await provider.retryConnection();
    if (!mounted) return;
    setState(() => _retrying = false);
  }

  Future<void> _saveHost(FeedingProvider provider) async {
    setState(() => _hostStatus = ActionStatus.loading);
    await provider.updateDeviceHost(hostController.text);
    if (!mounted) return;
    setState(() => _hostStatus = ActionStatus.success);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hostStatus = ActionStatus.idle);
    });
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();
    final reachable = provider.deviceReachable;
    final activeAlarms = provider.alarms.where((a) => a.enabled).length;

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
        title: const Text("Connection details", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: reachable ? const Color(0xFFE8F5E9) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  reachable ? Icons.check_circle : Icons.error_outline,
                  color: reachable ? const Color(0xFF4CAF50) : Colors.red.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reachable ? "Connected" : "Can't reach the feeder",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: reachable ? const Color(0xFF2E7D32) : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reachable
                            ? "The app is talking to the feeder at ${provider.deviceHost}."
                            : "Make sure your phone is on the same Wi-Fi/hotspot as the feeder, then retry.",
                        style: TextStyle(
                          fontSize: 12,
                          color: reachable ? const Color(0xFF2E7D32) : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!reachable && provider.deviceHost.contains(".local"))
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "If this phone is the one providing the hotspot, Android sometimes can't resolve its own petfeeder.local address, even though other devices on the same hotspot can. Enter the feeder's IP address below instead — it's shown in the feeder's Telegram startup message or the Serial Monitor.",
                      style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          const Text(
            "DEVICE ADDRESS",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            "Defaults to petfeeder.local (mDNS). If that doesn't resolve on your "
            "network, use the raw IP printed on the Serial Monitor or sent in the "
            "feeder's Telegram startup message instead.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: hostController,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveHost(provider),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text("Save address"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retrying ? null : () => _retry(provider),
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_retrying ? "Checking..." : "Retry now"),
                ),
              ),
            ],
          ),
          InlineStatusBanner(
            status: _hostStatus,
            loadingText: "Saving address...",
            successText: "Address saved — reconnecting",
          ),

          const SizedBox(height: 28),

          const Text(
            "WI-FI",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            "Manage saved networks, reconnect to one, or add a new one — the "
            "feeder remembers every network it's joined, like a phone's Wi-Fi "
            "settings.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          if (provider.wifiSwitchStatus == "testing")
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Testing a new network — this can take up to ~15 seconds.",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),

          if (provider.wifiSwitchStatus == "reverted" && provider.wifiSwitchReason.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Last switch didn't connect: ${provider.wifiSwitchReason}",
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WifiNetworksScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Wi-Fi networks", style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            "${provider.savedNetworks.length} saved",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            "LAST KNOWN STATE",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row("System", provider.systemOnline ? "Online" : "Unknown"),
                const Divider(height: 1),
                _row(
                  "Network (SSID)",
                  provider.connectedSsid.isEmpty ? "Unknown" : provider.connectedSsid,
                ),
                const Divider(height: 1),
                _row("Last fed", provider.lastFeed),
                const Divider(height: 1),
                _row("Next scheduled feed", provider.nextFeed),
                const Divider(height: 1),
                _row("Active feeding times", "$activeAlarms of ${provider.alarms.length}"),
                const Divider(height: 1),
                _row("Buzzer", provider.buzzerEnabled ? "On" : "Off"),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            "Fetched from the feeder's own /status endpoint, refreshed automatically every few seconds while the app is open.",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
