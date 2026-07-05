import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feeding_alarm.dart';

/// Talks to the ESP32 directly over the local Wi-Fi/hotspot network, using
/// the small HTTP API in the firmware (/feed, /status, /alarms, /buzzer).
/// This is the app's primary control channel.
///
/// (Why not through Telegram: Telegram never delivers one bot's messages to
/// another bot via getUpdates, so a second "app bot" can post commands into
/// the shared group all day and the ESP32's bot will never see them. See
/// telegram_service.dart's doc comment. That file is left in place — the
/// bot/group is still useful for human-to-device chat — but the app no
/// longer depends on it for control or status.)
class Esp32Service {
  /// Host or IP of the ESP32. Defaults to the mDNS hostname set in firmware
  /// (`MDNS.begin("petfeeder")`), which resolves on most phones/networks
  /// automatically. If mDNS doesn't resolve on your Wi-Fi, override with the
  /// raw IP printed on the Serial Monitor / sent in the Telegram startup
  /// message (e.g. "192.168.1.42") via [setHost] — wired to the Settings
  /// screen's "Device Address" field.
  String host = "petfeeder.local";

  Timer? _pollTimer;

  void Function(Esp32Status status)? onStatus;
  void Function(String error)? onError;

  void setHost(String newHost) {
    String h = newHost.trim();
    if (h.isEmpty) return;
    h = h.replaceFirst(RegExp(r'^https?://'), '');
    h = h.replaceAll(RegExp(r'/+$'), '');
    host = h;
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.http(host, path, query);

  /// Starts periodic status polling (default every 5s). Safe to call again
  /// after [setHost] changes to restart against the new address.
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => refreshStatus());
    refreshStatus();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshStatus() async {
    try {
      final res = await http.get(_uri("/status")).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        onStatus?.call(Esp32Status.fromJson(json));
      } else {
        onError?.call("Device replied with HTTP ${res.statusCode}");
      }
    } catch (_) {
      onError?.call("Could not reach device at $host");
    }
  }

  /// Triggers a manual dispense. Returns true only if the ESP32 accepted the
  /// request (HTTP 200) — actual dispense success still comes through the
  /// next /status poll or the Telegram confirmation message.
  Future<bool> feed() async {
    try {
      final res = await http.get(_uri("/feed")).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the device's current alarm list — the source of truth, since
  /// alarms can also be added/changed via Telegram (/setschedule, /schedule
  /// on|off). Returns null on failure so callers can tell "empty list" apart
  /// from "couldn't reach the device".
  Future<List<FeedingAlarm>?> fetchAlarms() async {
    try {
      final res = await http.get(_uri("/alarms")).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      return list.map((e) => FeedingAlarm.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Adds a new alarm (starts enabled). The device rejects duplicate times
  /// and enforces a max alarm count — returns null with no side effect if
  /// so, along with the message so the caller can show it.
  Future<Esp32AlarmResult> addAlarm(int hour, int minute) async {
    try {
      final res = await http
          .get(_uri("/addalarm", {"hour": hour.toString(), "minute": minute.toString()}))
          .timeout(const Duration(seconds: 5));
      return _parseAlarmResult(res);
    } catch (_) {
      return Esp32AlarmResult(ok: false, message: "Could not reach device at $host");
    }
  }

  Future<Esp32AlarmResult> removeAlarm(String id) async {
    try {
      final res = await http.get(_uri("/removealarm", {"id": id})).timeout(const Duration(seconds: 5));
      return _parseAlarmResult(res);
    } catch (_) {
      return Esp32AlarmResult(ok: false, message: "Could not reach device at $host");
    }
  }

  Future<Esp32AlarmResult> toggleAlarm(String id, bool enabled) async {
    try {
      final res = await http
          .get(_uri("/togglealarm", {"id": id, "on": enabled.toString()}))
          .timeout(const Duration(seconds: 5));
      return _parseAlarmResult(res);
    } catch (_) {
      return Esp32AlarmResult(ok: false, message: "Could not reach device at $host");
    }
  }

  Esp32AlarmResult _parseAlarmResult(http.Response res) {
    if (res.statusCode == 200) {
      try {
        final list = jsonDecode(res.body) as List;
        return Esp32AlarmResult(
          ok: true,
          alarms: list.map((e) => FeedingAlarm.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } catch (_) {
        return Esp32AlarmResult(ok: false, message: "Device sent back something unexpected");
      }
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return Esp32AlarmResult(ok: false, message: body['message']?.toString() ?? "Request failed");
    } catch (_) {
      return Esp32AlarmResult(ok: false, message: "Request failed (HTTP ${res.statusCode})");
    }
  }

  Future<bool> setBuzzer(bool enabled) async {
    try {
      final res = await http
          .get(_uri("/buzzer", {"on": enabled.toString()}))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends a candidate Wi-Fi network to the firmware. The ESP32 tests it
  /// itself (like a phone joining a new network) and reverts automatically
  /// if it doesn't connect within its own timeout — see the firmware's
  /// /setwifi handler. This call only confirms the request was received, not
  /// that the new network works; the actual outcome ("connected"/"reverted")
  /// arrives later via the normal /status poll's wifiSwitchStatus field, once
  /// the device (and hopefully this phone) are back on a shared network.
  Future<bool> setWifi(String ssid, String password) async {
    try {
      final res = await http
          .get(_uri("/setwifi", {"ssid": ssid, "password": password}))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the device's saved-networks list (names + which one is
  /// active) — passwords never come back over the wire. Returns null on
  /// failure so callers can tell "no saved networks" apart from
  /// "couldn't reach the device".
  Future<List<SavedNetwork>?> fetchNetworks() async {
    try {
      final res = await http.get(_uri("/networks")).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      return list.map((e) => SavedNetwork.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Reconnects to an already-saved network by name only — the device
  /// looks up its own stored password. Goes through the same test-and-
  /// revert flow as [setWifi].
  Future<Esp32NetworkResult> connectToNetwork(String ssid) async {
    try {
      final res = await http.get(_uri("/connectnetwork", {"ssid": ssid})).timeout(const Duration(seconds: 5));
      return _parseNetworkResult(res);
    } catch (_) {
      return Esp32NetworkResult(ok: false, message: "Could not reach device at $host");
    }
  }

  /// Removes a saved network. The device refuses to forget the one it's
  /// currently connected to.
  Future<Esp32NetworkResult> forgetNetwork(String ssid) async {
    try {
      final res = await http.get(_uri("/forgetnetwork", {"ssid": ssid})).timeout(const Duration(seconds: 5));
      return _parseNetworkResult(res);
    } catch (_) {
      return Esp32NetworkResult(ok: false, message: "Could not reach device at $host");
    }
  }

  Esp32NetworkResult _parseNetworkResult(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode == 200 && body['result'] == 'ok';
      return Esp32NetworkResult(ok: ok, message: body['message']?.toString() ?? '');
    } catch (_) {
      return Esp32NetworkResult(ok: false, message: "Request failed (HTTP ${res.statusCode})");
    }
  }
}

/// Parsed form of the firmware's /status JSON response.
class Esp32Status {
  final bool online;
  final String lastFeed;
  final String nextFeed;
  final bool buzzer;
  final String lastDetection;
  final String ssid;
  final String wifiSwitchStatus;
  final String wifiSwitchReason;

  Esp32Status({
    required this.online,
    required this.lastFeed,
    required this.nextFeed,
    required this.buzzer,
    this.lastDetection = '',
    this.ssid = '',
    this.wifiSwitchStatus = 'idle',
    this.wifiSwitchReason = '',
  });

  factory Esp32Status.fromJson(Map<String, dynamic> json) {
    return Esp32Status(
      online: json['online'] == true,
      lastFeed: json['lastFeed']?.toString() ?? '',
      nextFeed: json['nextFeed']?.toString() ?? '',
      buzzer: json['buzzer'] == true,
      lastDetection: json['lastDetection']?.toString() ?? '',
      ssid: json['ssid']?.toString() ?? '',
      wifiSwitchStatus: json['wifiSwitchStatus']?.toString() ?? 'idle',
      wifiSwitchReason: json['wifiSwitchReason']?.toString() ?? '',
    );
  }
}

/// Result of an alarm add/remove/toggle call. On success, [alarms] is the
/// device's full updated list (simplest way to stay in sync — no diffing).
class Esp32AlarmResult {
  final bool ok;
  final String message;
  final List<FeedingAlarm> alarms;

  Esp32AlarmResult({required this.ok, this.message = '', this.alarms = const []});
}

/// One entry in the device's saved-networks list (like a phone's Wi-Fi
/// settings). No password field — the device never sends those back.
class SavedNetwork {
  final String ssid;
  final bool active;

  SavedNetwork({required this.ssid, required this.active});

  factory SavedNetwork.fromJson(Map<String, dynamic> json) {
    return SavedNetwork(
      ssid: json['ssid']?.toString() ?? '',
      active: json['active'] == true,
    );
  }
}

/// Result of a connect/forget-network call.
class Esp32NetworkResult {
  final bool ok;
  final String message;

  Esp32NetworkResult({required this.ok, this.message = ''});
}
