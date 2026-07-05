import 'package:flutter/material.dart';

/// Replaces one-shot SnackBars for action feedback. Instead of popping a
/// toast after a dialog/popup has already closed, callers keep this widget
/// visible inline (inside the same popup or the same card) and flip
/// [ActionStatus] as the async call progresses — loading while in flight,
/// then success/error with the actual outcome, right where the user is
/// already looking.
enum ActionStatus { idle, loading, success, error }

class InlineStatusBanner extends StatelessWidget {
  final ActionStatus status;
  final String loadingText;
  final String successText;
  final String errorText;
  final EdgeInsetsGeometry margin;

  const InlineStatusBanner({
    super.key,
    required this.status,
    this.loadingText = "Working...",
    this.successText = "Done",
    this.errorText = "Something went wrong",
    this.margin = const EdgeInsets.only(top: 12),
  });

  @override
  Widget build(BuildContext context) {
    if (status == ActionStatus.idle) return const SizedBox.shrink();

    final isLoading = status == ActionStatus.loading;
    final isSuccess = status == ActionStatus.success;

    final Color color = isLoading
        ? Colors.grey.shade700
        : (isSuccess ? const Color(0xFF2E7D32) : Colors.red.shade700);
    final Color bg = isLoading
        ? Colors.grey.shade100
        : (isSuccess ? const Color(0xFFE8F5E9) : Colors.red.shade50);
    final String text = isLoading ? loadingText : (isSuccess ? successText : errorText);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: margin,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(isSuccess ? Icons.check_circle : Icons.error_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small trailing indicator meant to sit next to a Switch/IconButton
/// instead of a whole banner — used where space is tight (alarm rows, the
/// buzzer toggle). Shows nothing at idle, a spinner while loading, and a
/// self-fading check/error glyph on completion.
class InlineStatusDot extends StatelessWidget {
  final ActionStatus status;

  const InlineStatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ActionStatus.idle:
        return const SizedBox(width: 16, height: 16);
      case ActionStatus.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ActionStatus.success:
        return Icon(Icons.check_circle, size: 16, color: const Color(0xFF4CAF50));
      case ActionStatus.error:
        return Icon(Icons.error_outline, size: 16, color: Colors.red.shade400);
    }
  }
}

/// Mixin-like helper for State classes: runs an async action, flips a status
/// field through loading -> success/error, and automatically resets to idle
/// after a delay so the indicator doesn't linger forever. Callers still need
/// to call setState themselves around the status field since Dart mixins
/// can't easily share a generic field, so this is offered as a plain
/// function instead of a mixin.
Future<T> withStatus<T>({
  required void Function(ActionStatus) setStatus,
  required Future<T> Function() action,
  required bool Function(T) isSuccess,
  Duration resetAfter = const Duration(seconds: 3),
}) async {
  setStatus(ActionStatus.loading);
  final result = await action();
  setStatus(isSuccess(result) ? ActionStatus.success : ActionStatus.error);
  Future.delayed(resetAfter, () => setStatus(ActionStatus.idle));
  return result;
}
