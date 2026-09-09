// Tests for the synthesised warning tone.
//
// The audio plugin is not registered under flutter_test, so playback itself
// cannot be exercised here — what is checked is that the WAV we hand to
// audioplayers is well formed, and that the player degrades quietly instead of
// hanging or throwing when the platform is unavailable.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ourlandnew/services/warning_sound.dart';

/// Reads a little-endian unsigned 32-bit value at [offset].
int u32(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint32(offset, Endian.little);

int u16(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint16(offset, Endian.little);

String ascii(Uint8List b, int offset, int length) =>
    String.fromCharCodes(b.sublist(offset, offset + length));

void main() {
  group('synthesised tone', () {
    final bytes = WarningSound.debugToneBytes();

    test('is a canonical RIFF/WAVE file', () {
      expect(ascii(bytes, 0, 4), 'RIFF');
      expect(ascii(bytes, 8, 4), 'WAVE');
      expect(ascii(bytes, 12, 4), 'fmt ');
      expect(ascii(bytes, 36, 4), 'data');
    });

    test('declares 16-bit mono PCM at 44.1 kHz', () {
      expect(u32(bytes, 16), 16); // fmt chunk length
      expect(u16(bytes, 20), 1); // 1 = uncompressed PCM
      expect(u16(bytes, 22), 1); // mono
      expect(u32(bytes, 24), 44100); // sample rate
      expect(u16(bytes, 34), 16); // bits per sample
      // byteRate and blockAlign must agree with the above or players choke.
      expect(u32(bytes, 28), 44100 * 1 * 16 ~/ 8);
      expect(u16(bytes, 32), 1 * 16 ~/ 8);
    });

    test('its declared sizes match the actual byte count', () {
      final dataSize = u32(bytes, 40);
      expect(bytes.length, 44 + dataSize);
      // RIFF size counts everything after the first 8 bytes.
      expect(u32(bytes, 4), bytes.length - 8);
    });

    test('is about 0.66 s long — long enough to notice, short enough not to nag',
        () {
      final dataSize = u32(bytes, 40);
      final seconds = dataSize / (44100 * 2);
      expect(seconds, closeTo(0.66, 0.05));
    });

    test('actually contains sound, and never clips', () {
      final samples = Int16List.sublistView(bytes, 44);
      var peak = 0;
      var nonZero = 0;
      for (final s in samples) {
        final magnitude = s.abs();
        if (magnitude > peak) peak = magnitude;
        if (magnitude > 0) nonZero++;
      }
      // Loud enough to carry.
      expect(peak, greaterThan(15000));
      // But inside 16-bit range with headroom, so it does not distort.
      expect(peak, lessThan(32767));
      // Most of the file is tone rather than silence.
      expect(nonZero / samples.length, greaterThan(0.7));
    });

    test('starts and ends near silence, so there is no click', () {
      final samples = Int16List.sublistView(bytes, 44);
      expect(samples.first.abs(), lessThan(500));
      expect(samples.last.abs(), lessThan(500));
    });

    test('is deterministic, so it can be cached', () {
      expect(WarningSound.debugToneBytes(), equals(bytes));
    });
  });

  group('player behaviour without an audio plugin', () {
    tearDown(() async {
      WarningSound.disabled = false;
      await WarningSound.instance.disposePlayer();
    });

    test('play reports failure rather than throwing when disabled', () async {
      WarningSound.disabled = true;
      await expectLater(WarningSound.instance.play(), completion(isFalse));
    });

    test('stop is safe before anything has played', () async {
      WarningSound.disabled = true;
      await expectLater(WarningSound.instance.stop(), completes);
    });

    test('disposing a player that was never created is safe', () async {
      await expectLater(WarningSound.instance.disposePlayer(), completes);
    });

    test('repeated calls stay quiet and never throw', () async {
      WarningSound.disabled = true;
      for (var i = 0; i < 3; i++) {
        expect(await WarningSound.instance.play(), isFalse);
        await WarningSound.instance.stop();
      }
    });
  });
}
