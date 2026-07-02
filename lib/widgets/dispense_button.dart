import 'package:flutter/material.dart';

class DispenseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DispenseButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE27C2B), // Lighter orange
              Color(0xFFC75D14), // Darker orange
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD66B1E).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFFD66B1E).withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              "Dispense",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Manual Feed",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}