import 'package:duet/features/library/src/ui/library_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryFormat.greeting', () {
    DateTime at(int hour) => DateTime(2024, 1, 1, hour, 30);

    test('is "Good morning" from 05:00 up to (not incl.) 12:00', () {
      expect(LibraryFormat.greeting(now: at(5)), 'Good morning');
      expect(LibraryFormat.greeting(now: at(8)), 'Good morning');
      expect(LibraryFormat.greeting(now: at(11)), 'Good morning');
    });

    test('is "Good afternoon" from 12:00 up to (not incl.) 17:00', () {
      expect(LibraryFormat.greeting(now: at(12)), 'Good afternoon');
      expect(LibraryFormat.greeting(now: at(14)), 'Good afternoon');
      expect(LibraryFormat.greeting(now: at(16)), 'Good afternoon');
    });

    test('is "Good evening" from 17:00 through the small hours', () {
      expect(LibraryFormat.greeting(now: at(17)), 'Good evening');
      expect(LibraryFormat.greeting(now: at(20)), 'Good evening');
      expect(LibraryFormat.greeting(now: at(23)), 'Good evening');
      expect(LibraryFormat.greeting(now: at(0)), 'Good evening');
      expect(LibraryFormat.greeting(now: at(4)), 'Good evening');
    });
  });

  group('LibraryFormat.greetingFor', () {
    final morning = DateTime(2024, 1, 1, 8);

    test('appends the name when one is given', () {
      expect(
        LibraryFormat.greetingFor('Gil', now: morning),
        'Good morning, Gil',
      );
    });

    test('falls back to the bare greeting when the name is null', () {
      expect(LibraryFormat.greetingFor(null, now: morning), 'Good morning');
    });

    test('falls back to the bare greeting when the name is blank', () {
      expect(LibraryFormat.greetingFor('   ', now: morning), 'Good morning');
    });
  });

  group('LibraryFormat.welcome', () {
    test('appends the name when one is given', () {
      expect(LibraryFormat.welcome('Gil'), 'Welcome, Gil');
    });

    test('is bare "Welcome" when the name is null or blank', () {
      expect(LibraryFormat.welcome(null), 'Welcome');
      expect(LibraryFormat.welcome('  '), 'Welcome');
    });
  });
}
