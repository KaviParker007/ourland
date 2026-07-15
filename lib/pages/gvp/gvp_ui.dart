// ─── GVP Module — Shared UI helpers ───────────────────────────────────────────
//
// Small reusable state widgets + snackbars styled to match the Shift Dashboard
// module, so every GVP screen shares one loading / empty / error language.

import 'package:flutter/material.dart';

// ── Snackbars ─────────────────────────────────────────────────────────────────

void gvpSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
}

void gvpErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
}

// ── Full-page states ──────────────────────────────────────────────────────────

class GvpLoading extends StatelessWidget {
  const GvpLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class GvpFullError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const GvpFullError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(160)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class GvpEmpty extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData icon;

  const GvpEmpty({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(70)),
            const SizedBox(height: 14),
            Text(
              message,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Inline states (used inside expanded drill-down sections) ──────────────────

class GvpInlineLoader extends StatelessWidget {
  const GvpInlineLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class GvpInlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const GvpInlineError(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class GvpInlineEmpty extends StatelessWidget {
  final String message;
  const GvpInlineEmpty({super.key, this.message = 'No data'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Count badge (shared across drill-down levels) ─────────────────────────────

class GvpCountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const GvpCountBadge({
    super.key,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(110), width: 1.2),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}
