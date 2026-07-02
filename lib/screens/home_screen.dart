import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';
import '../widgets/dispense_button.dart';
import '../widgets/history_bottom_sheet.dart';
import '../widgets/pet_status_card.dart';
import '../widgets/schedule_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pets, color: AppTheme.darkPrimary, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        "Pet Feeder",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: AppTheme.darkPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              /// Pet Name (Outside the card in the design)
              Text(
                provider.petName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkPrimary,
                ),
              ),

              const SizedBox(height: 16),

              /// Pet Status Card
              const PetStatusCard(),

              const SizedBox(height: 48),

              /// Dispense Button
              Center(
                child: DispenseButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Dispense Food"),
                          content: const Text("Are you sure you want to dispense food now?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                context.read<FeedingProvider>().dispenseFood();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Food Dispensed Successfully")),
                                );
                              },
                              child: const Text("Dispense"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 48),

              /// Actions Row (Schedule & History)
              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      icon: Icons.schedule,
                      title: "Schedule",
                      iconColor: AppTheme.primaryColor,
                      iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ScheduleDialog(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ActionCard(
                      icon: Icons.history,
                      title: "History",
                       iconColor: AppTheme.primaryColor,
                      iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const HistoryBottomSheet(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}