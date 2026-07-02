import 'package:shared_preferences/shared_preferences.dart';

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
}