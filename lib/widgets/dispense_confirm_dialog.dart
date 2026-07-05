import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feeding_provider.dart';
import '../theme/app_theme.dart';
import 'inline_status.dart';

/// The dispense confirmation popup. Stays open through the whole action —
/// loading, then success/fail — instead of closing immediately and reporting
/// the outcome via a SnackBar afterward.
class DispenseConfirmDialog extends StatefulWidget {
  const DispenseConfirmDialog({super.key});

  @override
  State<DispenseConfirmDialog> createState() => _DispenseConfirmDialogState();
}

class _DispenseConfirmDialogState extends State<DispenseConfirmDialog> {
  ActionStatus _status = ActionStatus.idle;

  Future<void> _confirm() async {
    setState(() => _status = ActionStatus.loading);
    final ok = await context.read<FeedingProvider>().dispenseFood();
    if (!mounted) return;
    setState(() => _status = ok ? ActionStatus.success : ActionStatus.error);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _status == ActionStatus.loading;
    final done = _status == ActionStatus.success || _status == ActionStatus.error;

    return AlertDialog(
      title: const Text("Dispense food"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Are you sure you want to dispense food now?"),
          InlineStatusBanner(
            status: _status,
            loadingText: "Sending to the feeder...",
            successText: "Food dispensed successfully",
            errorText: "Couldn't reach the feeder — check you're on the same Wi-Fi/hotspot, then try again",
          ),
        ],
      ),
      actions: [
        if (!done) ...[
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: busy ? null : _confirm,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Dispense"),
          ),
        ] else ...[
          if (_status == ActionStatus.error)
            TextButton(onPressed: _confirm, child: const Text("Try again")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ],
    );
  }
}
