import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Talks to the Telegram Bot API using the Flutter app's OWN bot — a
/// *different* bot from the one the ESP32 firmware uses.
///
/// Why a second bot: Telegram never delivers a bot's own sendMessage calls
/// back to that same bot through getUpdates, so if this app used the
/// ESP32's bot token, the ESP32 would never see the commands as new
/// incoming messages. Both bots (and the owner's account) must be members
/// of one shared group — this app posts into that group, and the ESP32's
/// bot picks the message up as a normal incoming update.
///
/// Setup checklist (see project notes):
/// 1. Create a second bot via @BotFather, get its token.
/// 2. Create a group containing: owner's account, ESP32 bot, this app's bot.
/// 3. Disable "Group Privacy" for both bots via @BotFather so they see every
///    message in the group, not just ones that @-mention them.
/// 4. Get the group's chat_id (a negative number) and paste it below AND
///    into the ESP32 firmware's CHAT_ID.
class TelegramService {
  // TODO: paste the token BotFather gave you for the APP's bot.
  // Must NOT be the same token as the ESP32 firmware's BOT_TOKEN.
  static const String _botToken = "8833270279:AAFbtSGY5T-7oNGZ1r-_eYvCfQ4PeNPqSus";

  // TODO: paste the shared group's chat_id (negative number, e.g. -1001234567890).
  // Must match the CHAT_ID used in the ESP32 firmware.
  static const String _chatId = "-5334984304";

  static String get _base => "https://api.telegram.org/bot$_botToken";

  int _updateOffset = 0;
  Timer? _pollTimer;

  /// Fired for every new message seen in the group (alerts, confirmations,
  /// STATUS_JSON replies, anything). Useful for a raw activity/history feed.
  void Function(String rawText)? onMessage;

  /// Fired specifically when a message is a parsed STATUS_JSON reply.
  void Function(TelegramStatus status)? onStatus;

  /// True once real credentials have been filled in above. Callers can use
  /// this to fall back to mock/local behaviour until the team finishes the
  /// BotFather + group setup, instead of silently failing every call.
  bool get isConfigured =>
      !_botToken.startsWith("PASTE_") && !_chatId.startsWith("PASTE_");

  /// Starts polling the shared group for new messages. Safe to call once at
  /// app startup; calling again just restarts the timer.
  void startPolling({Duration interval = const Duration(seconds: 3)}) {
    if (!isConfigured) return; // no-op until real token/chat_id are set
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
    _poll(); // fetch immediately instead of waiting for the first tick
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    try {
      final uri = Uri.parse("$_base/getUpdates?offset=$_updateOffset&timeout=0");
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['result'] as List?) ?? const [];

      for (final update in results) {
        final updateId = update['update_id'] as int;
        _updateOffset = updateId + 1;

        final message = update['message'];
        if (message == null) continue;

        final chat = message['chat'];
        if (chat == null || chat['id'].toString() != _chatId) continue;

        final text = message['text'] as String?;
        if (text == null) continue;

        onMessage?.call(text);

        if (text.startsWith("STATUS_JSON:")) {
          final jsonPart = text.substring("STATUS_JSON:".length);
          try {
            final parsed = jsonDecode(jsonPart) as Map<String, dynamic>;
            onStatus?.call(TelegramStatus.fromJson(parsed));
          } catch (_) {
            // malformed status reply — ignore, next poll may get a clean one
          }
        }
      }
    } catch (_) {
      // network hiccup (hotspot drop, etc.) — next poll retries automatically
    }
  }

  Future<bool> _send(String text) async {
    if (!isConfigured) return false;
    try {
      final uri = Uri.parse("$_base/sendMessage");
      final res = await http
          .post(uri, body: {"chat_id": _chatId, "text": text})
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Posts "/feed" into the shared group — the ESP32 bot picks it up and
  /// triggers a manual dispense, exactly like typing it in Telegram yourself.
  Future<bool> sendFeedCommand() => _send("/feed");

  /// Asks the ESP32 for a fresh status reply (arrives async via onStatus).
  Future<bool> requestStatus() => _send("/status");

  /// Pushes a new daily feeding time to the firmware (persisted on-device).
  Future<bool> sendSchedule(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return _send("/setschedule $h:$m");
  }

  /// Toggles the scheduled-feed alarm buzzer on the firmware.
  Future<bool> sendBuzzerToggle(bool enabled) =>
      _send(enabled ? "/buzzer on" : "/buzzer off");
}

/// Parsed form of the firmware's `STATUS_JSON:{...}` reply to /status.
class TelegramStatus {
  final bool online;
  final String lastFeed;
  final String nextFeed;
  final bool buzzer;

  TelegramStatus({
    required this.online,
    required this.lastFeed,
    required this.nextFeed,
    required this.buzzer,
  });

  factory TelegramStatus.fromJson(Map<String, dynamic> json) {
    return TelegramStatus(
      online: json['online'] == true,
      lastFeed: json['lastFeed']?.toString() ?? '',
      nextFeed: json['nextFeed']?.toString() ?? '',
      buzzer: json['buzzer'] == true,
    );
  }
}
