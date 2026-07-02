import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';

class PetStatusCard extends StatelessWidget {
  const PetStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedingProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: provider.systemOnline ? AppTheme.onlineBg : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: provider.systemOnline ? AppTheme.onlineColor : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.systemOnline ? "SYSTEM ONLINE" : "OFFLINE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: provider.systemOnline ? AppTheme.onlineColor : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Last Fed
                Row(
                  children: [
                    Icon(Icons.history, size: 20, color: AppTheme.darkPrimary.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text(
                      "Last Fed: ${provider.lastFeed}",
                      style: TextStyle(
                        color: AppTheme.darkPrimary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Next Feed
                Row(
                  children: [
                    Icon(Icons.notifications_none, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "Next Feed: ${provider.nextFeed}",
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Dog Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              "assets/images/dog.jpg",
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.pets, size: 40, color: Colors.orange),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}