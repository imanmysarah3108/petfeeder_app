import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeding_provider.dart';
import '../services/esp32_service.dart';
import '../theme/app_theme.dart';
import '../widgets/inline_status.dart';

/// Saved Wi-Fi networks, styled like a phone's Wi-Fi settings: a list of
/// every network the feeder has ever connected to, with the active one
/// marked, tap-to-reconnect on the others, a Forget action, and an
/// "Add network" form for joining somewhere new. Replaces the old
/// single-slot "just overwrite the one saved network" behavior, which used
/// to make switching Wi-Fi forget whatever was connected before.
class WifiNetworksScreen extends StatefulWidget {
  const WifiNetworksScreen({super.key});

  @override
  State<WifiNetworksScreen> createState() => _WifiNetworksScreenState();
}

class _WifiNetworksScreenState extends State<WifiNetworksScreen> {
  bool _loadingList = true;
  final Map<String, ActionStatus> _rowStatus = {};
  final Map<String, String> _rowError = {};

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  ActionStatus _addStatus = ActionStatus.idle;
  String _addError = "";

  String? _lastSeenSwitchStatus;

  // Captured once here rather than re-fetched via context.read() later —
  // _onProviderChange is a raw ChangeNotifier listener callback, not a
  // widget lifecycle method, so it can fire at any time, including during
  // the brief window where this widget has been deactivated (e.g. mid pop
  // transition) but not yet disposed. Looking up an inherited widget via
  // context during that window throws "Looking up a deactivated widget's
  // ancestor is unsafe", which is exactly the crash this was causing right
  // after backing out of this screen. Holding a plain reference sidesteps
  // the lookup entirely.
  late final FeedingProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<FeedingProvider>();
    _lastSeenSwitchStatus = _provider.wifiSwitchStatus;
    _provider.addListener(_onProviderChange);
    _refresh();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChange);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Once a Wi-Fi switch (triggered from here or Connection Details) settles
  // into "connected" or "reverted", refresh the saved list so a
  // newly-added network shows up without the user having to pull to
  // refresh manually.
  void _onProviderChange() {
    final status = _provider.wifiSwitchStatus;
    if (status != _lastSeenSwitchStatus) {
      _lastSeenSwitchStatus = status;
      if (status == "connected" || status == "reverted") {
        _refresh();
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loadingList = true);
    await _provider.refreshNetworks();
    if (!mounted) return;
    setState(() => _loadingList = false);
  }

  void _setRowStatus(String ssid, ActionStatus status, {String error = ""}) {
    if (!mounted) return;
    setState(() {
      _rowStatus[ssid] = status;
      _rowError[ssid] = error;
    });
    if (status == ActionStatus.success || status == ActionStatus.error) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _rowStatus[ssid] = ActionStatus.idle);
      });
    }
  }

  Future<void> _connect(String ssid) async {
    _setRowStatus(ssid, ActionStatus.loading);
    final result = await _provider.connectToSavedNetwork(ssid);
    if (!mounted) return;
    _setRowStatus(ssid, result.ok ? ActionStatus.success : ActionStatus.error, error: result.message);
  }

  Future<void> _forget(String ssid) async {
    _setRowStatus(ssid, ActionStatus.loading);
    final result = await _provider.forgetNetwork(ssid);
    if (!mounted) return;
    if (!result.ok) {
      _setRowStatus(ssid, ActionStatus.error, error: result.message);
    }
    // On success the row disappears (list refreshes), nothing more to show.
  }

  Future<void> _addNetwork() async {
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty) {
      setState(() {
        _addStatus = ActionStatus.error;
        _addError = "Enter the network's name (SSID) first";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _addStatus = ActionStatus.idle);
      });
      return;
    }

    setState(() => _addStatus = ActionStatus.loading);
    final ok = await _provider.updateWifi(ssid, _passwordController.text);
    if (!mounted) return;
    setState(() {
      _addStatus = ok ? ActionStatus.success : ActionStatus.error;
      _addError = ok
          ? "Sent — testing '$ssid' now. It'll appear below once confirmed."
          : "Couldn't reach the feeder — check you're on the same Wi-Fi/hotspot, then try again";
    });
    if (ok) {
      _ssidController.clear();
      _passwordController.clear();
    }
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _addStatus = ActionStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();
    final networks = provider.savedNetworks;

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
        title: const Text("Wi-Fi networks", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _loadingList
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loadingList ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (provider.wifiSwitchStatus == "testing")
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                margin: const EdgeInsets.only(bottom: 16),
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

            const Text(
              "SAVED NETWORKS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "Every network the feeder has connected to stays remembered here — tap one to reconnect, or forget it to remove it.",
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            if (networks.isEmpty && !_loadingList)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    "No saved networks yet",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ...networks.map((network) {
                final rowStatus = _rowStatus[network.ssid] ?? ActionStatus.idle;
                final rowError = _rowError[network.ssid] ?? "";
                final busy = rowStatus == ActionStatus.loading;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: network.active ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          network.active ? Icons.wifi : Icons.wifi_outlined,
                          color: network.active ? AppTheme.primaryColor : Colors.grey.shade500,
                        ),
                        title: Text(
                          network.ssid,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: network.active ? AppTheme.darkPrimary : AppTheme.textDark,
                          ),
                        ),
                        subtitle: network.active
                            ? const Text("Connected", style: TextStyle(fontSize: 11.5, color: Color(0xFF4CAF50)))
                            : null,
                        onTap: (network.active || busy) ? null : () => _connect(network.ssid),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InlineStatusDot(status: rowStatus),
                            if (!network.active)
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
                                onPressed: busy ? null : () => _forget(network.ssid),
                              ),
                          ],
                        ),
                      ),
                      if (rowStatus == ActionStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              rowError.isNotEmpty ? rowError : "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again",
                              style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 28),

            const Text(
              "ADD A NEW NETWORK",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "The feeder tests it first and automatically switches back to its "
              "current network if it can't connect — like a phone joining Wi-Fi. "
              "Make sure your phone can also reach the new network.",
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
                controller: _ssidController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  labelText: "Network name (SSID)",
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: "Password",
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addStatus == ActionStatus.loading ? null : _addNetwork,
                icon: _addStatus == ActionStatus.loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add, size: 18),
                label: Text(_addStatus == ActionStatus.loading ? "Sending..." : "Add network"),
              ),
            ),
            InlineStatusBanner(
              status: _addStatus,
              loadingText: "Sending new Wi-Fi...",
              successText: _addError,
              errorText: _addError,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
