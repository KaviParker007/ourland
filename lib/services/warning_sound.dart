// ─── Warning sound ─────────────────────────────────────────────────────────────
//
// A short two-tone alert played when a warning dialog opens.
//
// The tone is synthesised in memory as a WAV rather than shipped as an asset:
// nothing to add to `pubspec.yaml`, nothing to keep in sync across platforms,
// and audioplayers accepts it through `BytesSource` on every target — including
// Flutter Web, where its implementation turns the bytes into a data URI.
//
// Lifecycle rules this class enforces:
//
//  • one shared AudioPlayer for the whole app, never one per dialog;
//  • one playback per call, stopping anything already sounding, so a rebuild or
//    a re-open cannot stack overlapping tones;
//  • every platform call is guarded — a muted device, a browser autoplay block
//    or a missing plugin must never surface as an error to the caller.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the app's warning cue. Use [WarningSound.instance].
class WarningSound {
  WarningSound._();

  static final WarningSound instance = WarningSound._();

  AudioPlayer? _player;
  Uint8List? _tone;

  /// True once a platform call has failed, so later calls skip straight to
  /// doing nothing rather than paying for a retry on every dialog.
  bool _unavailable = false;

  /// Turns the player off entirely.
  ///
  /// Set in widget tests, where no audio plugin is registered: `AudioPlayer`
  /// waits on a creation handshake that never completes without one, so a test
  /// would hang rather than fail. With this set, [play] reports failure straight
  /// away and callers take their fallback path.
  @visibleForTesting
  static bool disabled = false;

  /// Ceiling on any single platform round-trip. A wedged or slow audio backend
  /// must never hold up the dialog that asked for the tone.
  static const Duration _timeout = Duration(seconds: 3);

  /// Plays the warning tone from the start.
  ///
  /// Never throws: callers treat sound as optional. Returns true when playback
  /// was actually started — used to decide whether a fallback cue is needed.
  Future<bool> play() async {
    if (disabled || _unavailable) return false;
    try {
      await _startTone().timeout(_timeout);
      return true;
    } catch (_) {
      // Missing plugin, a browser autoplay block, a device with no audio route,
      // or a backend that stopped answering. Remembered so later opens skip
      // straight to the fallback instead of waiting again.
      _unavailable = true;
      return false;
    }
  }

  Future<void> _startTone() async {
    final player = _player ??= AudioPlayer(playerId: 'ourland_warning');
    // Treat this as an alarm rather than media: duck whatever else is playing
    // (music, navigation) for the half second the tone lasts instead of seizing
    // audio focus outright, and — via respectSilence: false, the default — sound
    // even when the device is on silent. A warning the user cannot hear because
    // their ringer is off would defeat the point.
    await player.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
        respectSilence: false,
      ).build(),
    );
    // ReleaseMode.stop keeps the prepared source around so repeat opens do not
    // re-decode, while still stopping rather than looping at the end.
    await player.setReleaseMode(ReleaseMode.stop);
    // Stop anything still sounding, so two opens in quick succession play one
    // tone from the top instead of overlapping.
    await player.stop();
    await player.setVolume(1);
    await player.play(
      BytesSource(_tone ??= _buildToneWav(), mimeType: 'audio/wav'),
    );
  }

  /// Stops playback. Safe to call when nothing is playing, or when the player
  /// was never created.
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop().timeout(_timeout);
    } catch (_) {
      // Already stopped, or the platform went away — nothing to recover from.
    }
  }

  /// Releases the shared player. The app has no shutdown hook, so this exists
  /// for tests and for a future teardown rather than being called in normal use.
  @visibleForTesting
  Future<void> disposePlayer() async {
    final player = _player;
    _player = null;
    _unavailable = false;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {
      // Nothing useful to do if the platform refuses.
    }
  }

  // ── Tone synthesis ───────────────────────────────────────────────────────────

  /// Two urgent beeps and a lower third — the shape of a machine alarm rather
  /// than a notification chime, so it reads as "something is wrong".
  ///
  /// Built once and cached; roughly 0.66 s of 16-bit mono PCM at 44.1 kHz.
  static Uint8List _buildToneWav() {
    const sampleRate = 44100;
    const bitsPerSample = 16;
    const channels = 1;

    // (frequency in Hz, duration in ms). A frequency of 0 is a silent gap.
    const segments = <(double, int)>[
      (880, 140),
      (0, 70),
      (880, 140),
      (0, 70),
      (660, 240),
    ];

    final samples = <int>[];
    for (final (frequency, millis) in segments) {
      final count = (sampleRate * millis / 1000).round();
      if (frequency == 0) {
        samples.addAll(List<int>.filled(count, 0));
        continue;
      }
      // An 8 ms ramp in and out of each beep. Without it the abrupt start and
      // stop of the waveform produces an audible click.
      final ramp = sampleRate * 0.008;
      for (var i = 0; i < count; i++) {
        var envelope = 1.0;
        if (i < ramp) {
          envelope = i / ramp;
        } else if (count - i < ramp) {
          envelope = (count - i) / ramp;
        }
        final value =
            math.sin(2 * math.pi * frequency * (i / sampleRate)) *
                envelope *
                0.6; // headroom, so the tone is loud but never clips
        samples.add((value * 32767).round().clamp(-32768, 32767));
      }
    }

    return _encodeWav(
      samples,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  }

  /// Wraps 16-bit PCM [samples] in a canonical 44-byte WAV header.
  static Uint8List _encodeWav(
    List<int> samples, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = samples.length * bitsPerSample ~/ 8;

    final bytes = ByteData(44 + dataSize);
    var offset = 0;

    void writeAscii(String value) {
      for (final unit in value.codeUnits) {
        bytes.setUint8(offset++, unit);
      }
    }

    void writeUint32(int value) {
      bytes.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    void writeUint16(int value) {
      bytes.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    writeAscii('RIFF');
    writeUint32(36 + dataSize); // size of everything after this field
    writeAscii('WAVE');

    writeAscii('fmt ');
    writeUint32(16); // PCM fmt chunk length
    writeUint16(1); // format 1 = uncompressed PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);

    writeAscii('data');
    writeUint32(dataSize);
    for (final sample in samples) {
      bytes.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }

  /// The synthesised WAV, exposed so tests can check the header without
  /// touching an audio plugin.
  @visibleForTesting
  static Uint8List debugToneBytes() => _buildToneWav();
}
