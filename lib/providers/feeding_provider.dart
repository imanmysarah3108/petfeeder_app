import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feeding_record.dart';
import '../services/storage_service.dart';

class FeedingProvider extends ChangeNotifier {
  // Pet Information
  String petName = "Buddy";
  String breed = "Golden Retriever";
  String weight = "12";
  String age = "3";

  // System Information
  bool systemOnline = true;

  String lastFeed = "08:30 AM";
  String nextFeed = "05:00 PM";

  bool buzzerEnabled = true;

  final List<FeedingRecord> history = [
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

Future<void> updateSchedule(
  String time,
  bool buzzer,
) async {
  nextFeed = time;
  buzzerEnabled = buzzer;

  await StorageService.saveSchedule(
    nextFeed: time,
    buzzerEnabled: buzzer,
  );

  notifyListeners();
}

  void dispenseFood() {
    final now = DateTime.now();

    final time = DateFormat('hh:mm a').format(now);

    lastFeed = time;

    history.insert(
      0,
      FeedingRecord(
        title: "Manual Feed",
        time: "Today • $time",
        amount: 50,
      ),
    );

    notifyListeners();
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

  notifyListeners();
}
}