import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feeding_record.dart';
import '../models/feeding_alarm.dart';
import '../services/storage_service.dart';
import '../services/esp32_service.dart';

class FeedingProvider extends ChangeNotifier {
  FeedingProvider() {
    _esp32.onStatus = _handleStatus;
    _esp32.onError = _handleError;
  }

  // Primary control/status channel — direct local HTTP to the ESP32.
  // (Telegram bot-to-bot messaging doesn't work for app control; see
  // telegram_service.dart and esp32_service.dart doc comments for why.)
  final Esp32Service _esp32 = Esp32Service();

  String get deviceHost => _esp32.host;
  bool _lastReachable = false;
  bool get deviceReachable => _lastReachable;

  // Pet Information
  String petName = "Buddy";
  String breed = "Golden Retriever";
  String weight = "12";
  String age = "3";
  String petPhoto = "preset:dog"; // "preset:<id>" or "file:<path>"

  // System Information — starts unknown/offline until the first /status
  // poll against the ESP32 succeeds.
  bool systemOnline = false;

  String lastFeed = "--:--";
  String nextFeed = "05:00 PM";

  bool buzzerEnabled = true;
  String connectedSsid = "";
  // idle | testing | connected | reverted — mirrors the firmware's own
  // state for an in-progress /setwifi switch.
  String wifiSwitchStatus = "idle";
  // Plain-English reason a switch reverted (wrong password, out of range,
  // 5GHz-only network, etc.) — empty when idle/testing/connected. Lets the
  // Wi-Fi Networks / Connection Details screens show WHY without the user
  // needing the Serial Monitor.
  String wifiSwitchReason = "";

  // Last time the ultrasonic sensor saw the pet at the feeder ("HH:MM"),
  // or empty if it hasn't happened since boot.
  String lastDetection = "";

  // Saved Wi-Fi networks (like a phone's Wi-Fi settings) — the device is the
  // source of truth. Refreshed via refreshNetworks() and after every
  // connect/forget.
  List<SavedNetwork> savedNetworks = [];

  // Saved feeding times (true multiple alarms — any number can be enabled
  // at once, each firing independently, like a phone's alarm clock). The
  // device is the source of truth; this list is refreshed from it via
  // refreshAlarms() and after every add/remove/toggle.
  List<FeedingAlarm> alarms = [];

  // Placeholder demo entries — only ever shown on a genuine first run,
  // before anything real has happened yet. Overwritten by whatever's in
  // storage as soon as loadData() runs (see there for why this needed to
  // become persisted instead of living only in memory).
  List<FeedingRecord> history = [
    FeedingRecord(
      title: "Automatic Morning Feed",
      time: "Today • 08:30 AM",
      amount: 50,
    ),
    FeedingRecord(
      title: "Manual Snack",
      time: "Yesterday • 03:20 PM",
      amount: 20,
    ),
  ];

  // Caps how many entries get kept/persisted, so the saved history doesn't
  // grow forever with long-term use.
  static const int _maxHistoryEntries = 100;

  // Distinguishes a scheduled (device-triggered) feed from one this app just
  // performed itself, so _handleStatus can log scheduled feeds too (they
  // previously never appeared in history at all) without double-logging a
  // manual one it already recorded directly.
  String _lastKnownFeedTime = "";
  DateTime? _lastManualFeedAt;

  Future<void> updatePetProfile({
    required String petName,
    required String breed,
    required String weight,
    required String age,
  }) async {
    this.petName = petName;
    this.breed = breed;
    this.weight = weight;
    this.age = age;

    await StorageService.savePetProfile(
      petName: petName,
      breed: breed,
      weight: weight,
      age: age,
    );

    notifyListeners();
  }

  /// Changes which host/IP the app talks to (Connection Details screen),
  /// persists it, and restarts polling against it.
  Future<void> updateDeviceHost(String host) async {
    _esp32.setHost(host);
    await StorageService.saveDeviceHost(_esp32.host);
    _esp32.startPolling();
    notifyListeners();
  }

  /// Manually re-checks the connection (Connection Details screen's Retry
  /// button) instead of waiting for the next automatic poll.
  Future<void> retryConnection() async {
    await _esp32.refreshStatus();
  }

  /// Sends a new Wi-Fi network for the feeder to try. The device tests it
  /// on its own and reverts automatically if it fails (see esp32_service.dart
  /// and the firmware's /setwifi handler) — this just confirms the request
  /// was delivered. Real outcome shows up later via [wifiSwitchStatus] once
  /// polling recovers, on whichever network the device ends up on.
  Future<bool> updateWifi(String ssid, String password) async {
    final ok = await _esp32.setWifi(ssid, password);
    _logActivity(
      ok
          ? "Sent new Wi-Fi '$ssid' — testing now, will revert automatically if it fails"
          : "Couldn't reach the feeder to send new Wi-Fi — check you're on the same network, then try again",
      success: ok,
      icon: Icons.wifi,
    );
    return ok;
  }

  /// Pulls the device's saved-networks list (names + which is active) —
  /// used to populate the Wi-Fi Networks page.
  Future<bool> refreshNetworks() async {
    final fetched = await _esp32.fetchNetworks();
    if (fetched != null) {
      savedNetworks = fetched;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Reconnects to an already-saved network by name — no password needed
  /// from the app, the device already has it stored. Goes through the same
  /// test-and-revert flow as [updateWifi].
  Future<Esp32NetworkResult> connectToSavedNetwork(String ssid) async {
    final result = await _esp32.connectToNetwork(ssid);
    _logActivity(
      result.ok
          ? "Reconnecting to '$ssid'"
          : (result.message.isNotEmpty ? result.message : "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again"),
      success: result.ok,
      icon: Icons.wifi,
    );
    return result;
  }

  /// Removes a saved network. The device refuses to forget the one it's
  /// currently connected to.
  Future<Esp32NetworkResult> forgetNetwork(String ssid) async {
    final result = await _esp32.forgetNetwork(ssid);
    if (result.ok) {
      savedNetworks = savedNetworks.where((n) => n.ssid != ssid).toList();
      notifyListeners();
    }
    return result;
  }

  /// Toggles the feeding-alarm buzzer, independent of which alarm is active.
  /// Returns whether the device actually accepted the change.
  Future<bool> updateBuzzer(bool enabled) async {
    buzzerEnabled = enabled;
    notifyListeners();

    await StorageService.saveSchedule(nextFeed: nextFeed, buzzerEnabled: enabled);
    final ok = await _esp32.setBuzzer(enabled);

    _logActivity(
      ok
          ? "Buzzer turned ${enabled ? 'on' : 'off'}"
          : "Couldn't reach the feeder — check you're on the same Wi-Fi, then try again",
      success: ok,
      icon: Icons.notifications_none,
    );

    await _esp32.refreshStatus();
    return ok;
  }

  /// Pulls the current alarm list from the device — the source of truth,
  /// since alarms can also be added/changed via Telegram. Called on load and
  /// whenever the Alarms page wants a fresh copy (it also refreshes itself
  /// after every add/remove/toggle from that call's own response, so this is
  /// mostly for the initial load).
  Future<bool> refreshAlarms() async {
    final fetched = await _esp32.fetchAlarms();
    if (fetched != null) {
      alarms = fetched;
      await StorageService.saveAlarms(alarms);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Adds a new saved feeding time — starts enabled right away. True
  /// multiple alarms now: no "only one can be on" constraint.
  Future<Esp32AlarmResult> addAlarm(TimeOfDay time) async {
    final result = await _esp32.addAlarm(time.hour, time.minute);
    if (result.ok) {
      alarms = result.alarms;
      await StorageService.saveAlarms(alarms);
      _logActivity("Feeding time added for ${_formatTime(time.hour, time.minute)}", success: true, icon: Icons.alarm_add);
    }
    notifyListeners();
    return result;
  }

  Future<Esp32AlarmResult> deleteAlarm(String id) async {
    final result = await _esp32.removeAlarm(id);
    if (result.ok) {
      alarms = result.alarms;
      await StorageService.saveAlarms(alarms);
      _logActivity("Feeding time removed", success: true, icon: Icons.delete_outline);
    }
    notifyListeners();
    return result;
  }

  /// Turns one alarm on or off — independent of every other alarm; any
  /// number can be enabled at the same time now.
  Future<Esp32AlarmResult> setAlarmEnabled(String id, bool enabled) async {
    final result = await _esp32.toggleAlarm(id, enabled);
    if (result.ok) {
      alarms = result.alarms;
      await StorageService.saveAlarms(alarms);
      _logActivity(
        enabled ? "Feeding time turned on" : "Feeding time turned off",
        success: true,
        icon: enabled ? Icons.alarm : Icons.alarm_off,
      );
    }
    notifyListeners();
    return result;
  }

  String _formatTime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12raw = hour % 12;
    final h12 = h12raw == 0 ? 12 : h12raw;
    return "${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period";
  }

  Future<void> updatePetPhoto(String reference) async {
    petPhoto = reference;
    await StorageService.savePetPhoto(reference);
    notifyListeners();
  }

  /// Triggers a manual feed via the ESP32's local HTTP API, logs the
  /// outcome, and returns whether the device actually accepted it — the
  /// caller (Dispense button) uses this for a real success/failure message.
  Future<bool> dispenseFood() async {
    final accepted = await _esp32.feed();

    if (accepted) {
      // Confirmed dispense details (lastFeed etc.) arrive via the next
      // /status poll rather than being guessed here. Marking the time now
      // lets _handleStatus tell this manual feed apart from a scheduled one
      // when that poll's lastFeed value changes, so it doesn't also log a
      // duplicate "Scheduled feeding" entry for the very same dispense.
      _lastManualFeedAt = DateTime.now();
      _addHistoryEntry(
        FeedingRecord(
          title: "Manual Feed",
          time: "Today • ${DateFormat('hh:mm a').format(DateTime.now())}",
          amount: 50,
          success: true,
        ),
      );
      await _esp32.refreshStatus();
    } else {
      _logActivity(
        "Manual feed failed — couldn't reach the feeder. Check you're on the same Wi-Fi, then try again",
        success: false,
        icon: Icons.restaurant,
      );
    }

    return accepted;
  }

  /// Adds an entry to the combined activity/feeding log shown in the
  /// History sheet. Used for anything that isn't a confirmed dispense
  /// (schedule changes, buzzer toggles, failed commands).
  void _logActivity(String title, {required bool success, IconData icon = Icons.info_outline}) {
    final time = DateFormat('hh:mm a').format(DateTime.now());
    _addHistoryEntry(FeedingRecord(title: title, time: "Today • $time", success: success, icon: icon));
  }

  /// Inserts one entry, trims the list to [_maxHistoryEntries], notifies,
  /// and persists — the single path everything above should go through so
  /// history can't drift out of sync with what's saved.
  void _addHistoryEntry(FeedingRecord record) {
    history.insert(0, record);
    if (history.length > _maxHistoryEntries) {
      history.removeRange(_maxHistoryEntries, history.length);
    }
    notifyListeners();
    unawaited(StorageService.saveHistory(history));
  }

  int _consecutiveFailures = 0;

  void _handleStatus(Esp32Status status) {
    _consecutiveFailures = 0;
    _lastReachable = true;
    systemOnline = status.online;
    if (status.lastFeed.isNotEmpty) lastFeed = status.lastFeed;
    if (status.nextFeed.isNotEmpty) nextFeed = status.nextFeed;
    buzzerEnabled = status.buzzer;
    if (status.ssid.isNotEmpty) connectedSsid = status.ssid;

    // Log a completed feed the moment lastFeed changes — this is what
    // catches SCHEDULED feeds for history. Previously only a manual dispense
    // triggered through this app got logged (inserted directly by
    // dispenseFood()); a feed fired autonomously by the ESP32's own alarm
    // clock never showed up in the activity list at all. Guarded against:
    // the firmware's "Never" placeholder, the very first sync after app
    // start, and a feed this app JUST performed itself (already logged
    // directly in dispenseFood() — without this guard it'd get double-logged
    // a few seconds later once this same change reached /status).
    if (status.lastFeed.isNotEmpty && status.lastFeed != "Never" && status.lastFeed != _lastKnownFeedTime) {
      final isFirstSync = _lastKnownFeedTime.isEmpty;
      final recentlyManual = _lastManualFeedAt != null &&
          DateTime.now().difference(_lastManualFeedAt!) < const Duration(seconds: 20);
      _lastKnownFeedTime = status.lastFeed;
      if (!isFirstSync && !recentlyManual) {
        _logActivity("Scheduled feeding complete ($_lastKnownFeedTime)", success: true, icon: Icons.restaurant);
      }
    }

    // Surface a pet-detection event the moment it changes — previously this
    // only went to Telegram and never reached the app at all. Guard against
    // the firmware's "Never" placeholder and against the very first sync
    // after app start (otherwise every cold start would log a fake
    // "detected" the instant the first /status reply arrives).
    if (status.lastDetection.isNotEmpty && status.lastDetection != lastDetection) {
      final isFirstSync = lastDetection.isEmpty;
      lastDetection = status.lastDetection;
      if (!isFirstSync && lastDetection != "Never") {
        _logActivity("Pet detected at the feeder", success: true, icon: Icons.pets);
      }
    }

    // Log the outcome of a Wi-Fi switch exactly once, the moment it changes
    // from "testing" to a final state — this is the feedback loop for the
    // /setwifi flow, riding on the same /status polling everything else uses.
    if (status.wifiSwitchStatus != wifiSwitchStatus) {
      wifiSwitchReason = status.wifiSwitchReason;
      if (status.wifiSwitchStatus == "connected") {
        _logActivity("Wi-Fi switched to '${status.ssid}'", success: true, icon: Icons.wifi);
      } else if (status.wifiSwitchStatus == "reverted") {
        // status.wifiSwitchReason comes straight from the firmware's own
        // WiFi.status() at the moment the test failed (see
        // wifiStatusReason() in the firmware) — tells you whether it was a
        // wrong password, an out-of-range/5GHz-only network, etc. instead
        // of just "didn't connect".
        final reason = status.wifiSwitchReason.isNotEmpty ? " — ${status.wifiSwitchReason}" : "";
        _logActivity(
          "New Wi-Fi didn't connect$reason. Reverted to '${status.ssid}'",
          success: false,
          icon: Icons.wifi_off,
        );
      }
      wifiSwitchStatus = status.wifiSwitchStatus;
    }

    notifyListeners();
  }

  void _handleError(String error) {
    // Require 3 consecutive failed polls before flagging the device as
    // unreachable — a single missed poll (e.g. one that lands mid-dispense
    // or mid Telegram-send on the firmware side) shouldn't flip the whole UI
    // to "disconnected".
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      _lastReachable = false;
      systemOnline = false;
      notifyListeners();
    }
  }

  Future<void> loadData() async {
    final pet = await StorageService.loadPetProfile();

    petName = pet['petName']!;
    breed = pet['breed']!;
    weight = pet['weight']!;
    age = pet['age']!;

    final schedule = await StorageService.loadSchedule();

    nextFeed = schedule['nextFeed'];
    buzzerEnabled = schedule['buzzerEnabled'];

    petPhoto = await StorageService.loadPetPhoto();
    alarms = await StorageService.loadAlarms();

    // Restore the activity log so it survives an app restart instead of
    // resetting to the placeholder demo entries — only falls back to those
    // on a genuine first run (loadHistory returns null, not [], when
    // nothing's been saved yet).
    final savedHistory = await StorageService.loadHistory();
    if (savedHistory != null) {
      history = savedHistory;
    }

    final host = await StorageService.loadDeviceHost();
    _esp32.setHost(host);

    notifyListeners();

    _esp32.startPolling();
    // Local alarms above are just a cache for instant rendering — sync the
    // real list from the device right after (it's also the source of truth
    // if alarms were added/changed via Telegram instead of the app).
    unawaited(refreshAlarms());
    unawaited(refreshNetworks());
  }

  @override
  void dispose() {
    _esp32.stopPolling();
    super.dispose();
  }
}
