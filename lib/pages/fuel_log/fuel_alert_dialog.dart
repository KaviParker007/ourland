// ─── Add Fuel Log — warning dialog ─────────────────────────────────────────────
//
// Shown when `drf_get_last_fueling_detail/` returned `alert: true`, gating the
// save so the user cannot submit past a warning by accident. It is advisory, not
// a validation failure: "Continue Anyway" proceeds with the normal flow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ourlandnew/services/warning_sound.dart';

import 'last_fueling_detail.dart';

/// Plays the warning cue: a synthesised two-tone alarm through the shared
/// [WarningSound] player, plus a heavy haptic on devices that have one.
///
/// If the audio player is unavailable — no plugin, a browser autoplay block, a
/// device with no audio route — it falls back to the platform alert tone, so
/// something is still heard wherever possible. Every step is guarded
/// independently: one failing must not skip the others, and none of them may
/// surface an error, because sound is optional and the dialog is not.
Future<void> playFuelWarningSound() async {
  var played = false;
  try {
    played = await WarningSound.instance.play();
  } catch (_) {
    // WarningSound already swallows its own failures; this is belt and braces.
  }

  if (!played) {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Device muted, unsupported platform, or channel error — not fatal.
    }
  }

  try {
    await HapticFeedback.heavyImpact();
  } catch (_) {
    // No vibrator, or permission withheld — not fatal.
  }
}

/// Stops the warning cue. Called when the dialog closes so a tone cannot outlive
/// the warning that prompted it.
Future<void> stopFuelWarningSound() => WarningSound.instance.stop();

/// Shows the warning and resolves to true only when the user chose to continue.
///
/// Dismissing by tapping outside or pressing back resolves to false, so an
/// accidental dismissal cancels rather than submits.
Future<bool> showFuelAlertDialog(
  BuildContext context,
  LastFuelingDetail detail,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FuelAlertDialog(detail: detail),
  );
  return result ?? false;
}

/// Local `unawaited` so the sound never delays the dialog appearing and a
/// failure inside it cannot surface as an unhandled async error.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}

class _FuelAlertDialog extends StatefulWidget {
  final LastFuelingDetail detail;
  const _FuelAlertDialog({required this.detail});

  @override
  State<_FuelAlertDialog> createState() => _FuelAlertDialogState();
}

class _FuelAlertDialogState extends State<_FuelAlertDialog> {
  @override
  void initState() {
    super.initState();
    // Tied to the dialog's lifetime rather than to showFuelAlertDialog, so the
    // tone fires exactly once per open — a rebuild does not retrigger it — and
    // is guaranteed to be stopped in dispose below.
    unawaited(playFuelWarningSound());
  }

  @override
  void dispose() {
    // Whichever way the dialog closed — Cancel, Continue, or a route pop — the
    // tone does not outlive it.
    unawaited(stopFuelWarningSound());
    super.dispose();
  }

  LastFuelingDetail get detail => widget.detail;

  /// Amber rather than the theme's error red: this is a warning the user is
  /// expected to be able to pass, not a failure.
  static const Color _warning = Color(0xFFF9A825);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final media = MediaQuery.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: _warning.withAlpha(120), width: 1.4),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _warning.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fuel Log Warning',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: onSurface,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        // Caps the height so many messages scroll instead of pushing the
        // buttons off-screen, and the width so it reads well on a tablet or
        // desktop window rather than stretching edge to edge.
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: media.size.height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.hasAlertMessages)
                ...[
                  for (var i = 0; i < detail.alertMessages.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _messageTile(detail.alertMessages[i], onSurface),
                  ],
                ]
              else
                // alert was true with no text. Say so plainly rather than
                // inventing a warning message on the frontend.
                _messageTile(
                  'The server flagged a warning for this vehicle but did not '
                  'provide any details.',
                  onSurface,
                ),
              const SizedBox(height: 14),
              Text(
                'You can continue and save this fuel log anyway.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
      // AlertDialog lays actions out in an OverflowBar, which already stacks
      // them vertically when two long labels will not fit side by side — so a
      // narrow phone or a large text scale wraps instead of overflowing.
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: onSurface.withAlpha(180)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _warning,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Continue Anyway'),
        ),
      ],
    );
  }

  Widget _messageTile(String message, Color onSurface) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _warning.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _warning.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: _warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: onSurface.withAlpha(230),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline banner ──────────────────────────────────────────────────────────────

/// The same warning shown passively inside the Last Fueling Details panel, so
/// the user sees it while filling the form rather than only at submit time.
///
/// Styled for that panel's light surface, unlike the dialog which sits on the
/// app's dark theme.
class FuelAlertBanner extends StatelessWidget {
  final LastFuelingDetail detail;
  const FuelAlertBanner({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    if (!detail.shouldWarn) return const SizedBox.shrink();

    final messages = detail.hasAlertMessages
        ? detail.alertMessages
        : const ['A warning was flagged for this vehicle.'];

    return Semantics(
      liveRegion: true,
      label: 'Warning. ${messages.join('. ')}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warning',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  for (final m in messages)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
