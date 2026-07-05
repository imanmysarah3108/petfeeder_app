import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pet_profile_screen.dart';
import 'connection_details_screen.dart';
import 'feeding_alarms_screen.dart';
import 'thingspeak_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _navRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "GENERAL",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _navRow(
            context: context,
            icon: Icons.pets,
            title: "Pet profile",
            subtitle: "Name, breed, weight, age, and photo",
            destination: const PetProfileScreen(),
          ),
          _navRow(
            context: context,
            icon: Icons.schedule,
            title: "Feeding schedule",
            subtitle: "Saved times and the feeding buzzer",
            destination: const FeedingAlarmsScreen(),
          ),
          _navRow(
            context: context,
            icon: Icons.wifi_outlined,
            title: "Connection details",
            subtitle: "Device address and live status",
            destination: const ConnectionDetailsScreen(),
          ),
          _navRow(
            context: context,
            icon: Icons.insights_outlined,
            title: "Cloud analytics",
            subtitle: "Live ThingSpeak charts",
            destination: const ThingSpeakScreen(),
          ),
        ],
      ),
    );
  }
}
