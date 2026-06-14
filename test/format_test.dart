import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kbannerguider/utils/format.dart';

void main() {
  group('formatMeters', () {
    test('returns metres string below 1000', () {
      expect(formatMeters(0), '0 m');
      expect(formatMeters(999), '999 m');
    });

    test('returns km string at exactly 1000', () {
      expect(formatMeters(1000), '1.0 km');
    });

    test('returns km string above 1000', () {
      expect(formatMeters(2500), '2.5 km');
      expect(formatMeters(10000), '10.0 km');
    });
  });

  group('factionColor', () {
    test('ENLIGHTENED maps to green', () {
      expect(factionColor('ENLIGHTENED'), Colors.green);
    });

    test('ENL maps to green', () {
      expect(factionColor('ENL'), Colors.green);
    });

    test('RESISTANCE maps to blue', () {
      expect(factionColor('RESISTANCE'), Colors.blue);
    });

    test('RES maps to blue', () {
      expect(factionColor('RES'), Colors.blue);
    });

    test('unknown faction maps to grey', () {
      expect(factionColor('UNKNOWN'), Colors.grey);
      expect(factionColor(''), Colors.grey);
    });

    test('null maps to grey', () {
      expect(factionColor(null), Colors.grey);
    });
  });

  group('missionColor', () {
    test('first index returns first colour', () {
      expect(missionColor(0), missionColors.first);
    });

    test('wraps around the colour list', () {
      expect(missionColor(missionColors.length), missionColors.first);
      expect(missionColor(missionColors.length + 1), missionColors[1]);
    });
  });
}
