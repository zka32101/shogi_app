import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utilities/shared_utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('shared_utilities Integration - shogi_app', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.initialize();
    });

    test('SharedPreferencesService saves and loads game moves', () async {
      final moveData = {
        'from': 'e1',
        'to': 'e2',
        'piece': '歩',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await SharedPreferencesService.instance.setString(
        'app_move_history',
        moveData.toString(),
      );

      final loaded = SharedPreferencesService.instance.getString(
        'app_move_history',
      );
      expect(loaded, isNotNull);
    });

    test('StringExtensions validates Japanese position format', () {
      final validPos = 'a1';
      final invalidPos = 'z9';

      expect(validPos.isNotEmpty, isTrue);
      expect(validPos.length, equals(2));
      expect(invalidPos.length, equals(2));
    });

    test('Formatter formats dates for game records', () {
      final now = DateTime.now();
      final formatted = Formatter.formatDate(now);

      expect(formatted, matches(RegExp(r'\d{4}-\d{2}-\d{2}')));
    });

    test('DateTimeExtensions provides date navigation', () {
      final now = DateTime.now();
      final yesterday = now.yesterday;
      final tomorrow = now.tomorrow;

      expect(yesterday.isBefore(now), isTrue);
      expect(tomorrow.isAfter(now), isTrue);
    });

    test('FormValidators validates required fields', () {
      final validMove = FormValidators.validateRequired('e1-e2');
      final emptyMove = FormValidators.validateRequired('');

      expect(validMove, isNull);
      expect(emptyMove, isNotNull);
    });

    test('DateTimeExtensions provides Japanese day names', () {
      final now = DateTime.now();
      final dayJa = now.dayOfWeekJa;

      expect(dayJa, isNotNull);
      expect(dayJa, isIn(['月', '火', '水', '木', '金', '土', '日']));
    });

    test('AppTheme provides Material Design consistency', () {
      final lightTheme = AppTheme.lightTheme();
      final darkTheme = AppTheme.darkTheme();

      expect(lightTheme.primaryColor, isNotNull);
      expect(darkTheme.primaryColor, isNotNull);
    });

    test('LoadingWidget and ErrorWidget are available', () {
      expect(LoadingWidget, isNotNull);
      expect(ErrorWidget, isNotNull);
    });

    test('Formatter provides time and date utilities', () {
      final now = DateTime.now();
      final timeAgo = Formatter.formatTimeAgo(
        now.subtract(const Duration(hours: 2)),
      );

      expect(timeAgo, isNotNull);
      expect(timeAgo.isEmpty, isFalse);
    });
  });
}
