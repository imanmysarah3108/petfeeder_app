import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/feeding_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final provider = FeedingProvider();
        provider.loadData();
        return provider;
      },
      child: const PetFeederApp(),
    ),
  );
}

class PetFeederApp extends StatelessWidget {
  const PetFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Feeder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}