import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feeding_alarm.dart';
import '../models/feeding_record.dart';

class StorageService {
  static Future<void> savePetProfile({
    required String petName,
    required String breed,
    required String weight,
    required String age,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('petName', petName);
    await prefs.setString('breed', breed);
    await prefs.setString('weight', weight);
    await prefs.setString('age', age);
  }

  static Future<Map<String, String>> loadPetProfile() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'petName': prefs.getString('petName') ?? 'Buddy',
      'breed': prefs.getString('breed') ?? 'Golden Retriever',
      'weight': prefs.getString('weight') ?? '12',
      'age': prefs.getString('age') ?? '3',
    };
  }

  static Future<void> saveSchedule({
    required String nextFeed,
    required bool buzzerEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('nextFeed', nextFeed);
    await prefs.setBool('buzzerEnabled', buzzerEnabled);
  }

  static Future<Map<String, dynamic>> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'nextFeed': prefs.getString('nextFeed') ?? '05:00 PM',
      'buzzerEnabled': prefs.getBool('buzzerEnabled') ?? true,
    };
  }

  /// Where the ESP32 lives on the local network. Defaults to the mDNS
  /// hostname the firmware advertises; overridden if mDNS doesn't resolve
  /// on a given phone/network and the team types the raw IP instead.
  static Future<void> saveDeviceHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceHost', host);
  }

  static Future<String> loadDeviceHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deviceHost') ?? 'petfeeder.local';
  }

  /// Local cache of the device's alarm list, so the Alarms page has
  /// something to show instantly on open instead of a blank loading state —
  /// it's refreshed from the ESP32 (the real source of truth) right after.
  static Future<void> saveAlarms(List<FeedingAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString('feedingAlarms', raw);
  }

  static Future<List<FeedingAlarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('feedingAlarms');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => FeedingAlarm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Pet photo reference: either "preset:<id>" for a bundled avatar or
  /// "file:<path>" for a photo picked from the camera/gallery.
  static Future<void> savePetPhoto(String reference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('petPhoto', reference);
  }

  static Future<String> loadPetPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('petPhoto') ?? 'preset:dog';
  }

  /// The "Recent activity" / History log. Previously never persisted at
  /// all — it lived only in the provider's in-memory list, so it silently
  /// reset to the two placeholder demo entries every time the app process
  /// was restarted (including Android killing it in the background), which
  /// looked like the whole activity list had "disappeared".
  static Future<void> saveHistory(List<FeedingRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString('feedingHistory', raw);
  }

  /// Returns null (not an empty list) when nothing has been saved yet, so
  /// the caller can tell "no history saved" apart from "user cleared it"
  /// and fall back to the starter demo entries only on a genuine first run.
  static Future<List<FeedingRecord>?> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('feedingHistory');
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => FeedingRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
}