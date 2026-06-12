import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents a single item in the spaced repetition system
class SRSItem {
  final String problemId;
  DateTime nextReviewDate;
  double easyFactor;
  int repetitions;
  int interval;

  SRSItem({
    required this.problemId,
    required this.nextReviewDate,
    this.easyFactor = 2.5,
    this.repetitions = 0,
    this.interval = 0,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'problemId': problemId,
      'nextReviewDate': nextReviewDate.toIso8601String(),
      'easyFactor': easyFactor,
      'repetitions': repetitions,
      'interval': interval,
    };
  }

  /// Create from JSON
  factory SRSItem.fromJson(Map<String, dynamic> json) {
    return SRSItem(
      problemId: json['problemId'] as String,
      nextReviewDate: DateTime.parse(json['nextReviewDate'] as String),
      easyFactor: (json['easyFactor'] as num).toDouble(),
      repetitions: json['repetitions'] as int,
      interval: json['interval'] as int,
    );
  }
}

/// SM-2 Spaced Repetition System service
/// Implements the SM-2 algorithm for optimal spacing intervals
class SpacedRepetitionService {
  static const String _storageKey = 'srs_items_json';
  late SharedPreferences _prefs;

  SpacedRepetitionService();

  /// Initialize the service with SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get all SRS items
  List<SRSItem> _getAllItems() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((item) => SRSItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save all SRS items
  Future<void> _saveAllItems(List<SRSItem> items) async {
    final jsonString = jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  /// Add a problem to the SRS queue
  /// [problemId]: unique identifier for the problem
  /// [failedDate]: optional date when the problem was failed (defaults to today)
  Future<void> addProblem(String problemId, {DateTime? failedDate}) async {
    final items = _getAllItems();

    // Check if problem already exists
    final existingIndex = items.indexWhere((item) => item.problemId == problemId);
    if (existingIndex >= 0) {
      // Problem already exists, don't add duplicate
      return;
    }

    // Create new SRS item with first review due today
    final newItem = SRSItem(
      problemId: problemId,
      nextReviewDate: failedDate ?? DateTime.now(),
      easyFactor: 2.5,
      repetitions: 0,
      interval: 0,
    );

    items.add(newItem);
    await _saveAllItems(items);
  }

  /// Get all problems due for review today
  List<SRSItem> getReviewsDue() {
    final items = _getAllItems();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return items
        .where((item) {
          final reviewDate = DateTime(item.nextReviewDate.year,
              item.nextReviewDate.month, item.nextReviewDate.day);
          return reviewDate.isBefore(todayDate) || reviewDate.isAtSameMomentAs(todayDate);
        })
        .toList();
  }

  /// Get all problems overdue (before today)
  List<SRSItem> getReviewsOverdue() {
    final items = _getAllItems();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return items
        .where((item) {
          final reviewDate = DateTime(item.nextReviewDate.year,
              item.nextReviewDate.month, item.nextReviewDate.day);
          return reviewDate.isBefore(todayDate);
        })
        .toList();
  }

  /// Get upcoming reviews for the next N days
  List<SRSItem> getUpcomingReviews({int days = 7}) {
    final items = _getAllItems();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final futureDate =
        todayDate.add(Duration(days: days));

    return items
        .where((item) {
          final reviewDate = DateTime(item.nextReviewDate.year,
              item.nextReviewDate.month, item.nextReviewDate.day);
          return (reviewDate.isAfter(todayDate) && reviewDate.isBefore(futureDate)) ||
              reviewDate.isAtSameMomentAs(futureDate);
        })
        .toList();
  }

  /// Update an item after review using SM-2 algorithm
  /// [problemId]: problem identifier
  /// [correct]: whether the review was answered correctly (quality >= 3)
  /// [quality]: quality of response (0-5), where:
  ///   - 0-2: incorrect/poor response (interval resets)
  ///   - 3-4: acceptable response
  ///   - 5: perfect response
  Future<void> updateAfterReview(
    String problemId, {
    required bool correct,
    int quality = 5,
  }) async {
    final items = _getAllItems();
    final index = items.indexWhere((item) => item.problemId == problemId);

    if (index < 0) {
      return; // Item not found
    }

    final item = items[index];

    // Adjust quality based on correct/incorrect
    if (!correct && quality > 2) {
      quality = 2; // Force incorrect answers to quality 2 or below
    }

    // SM-2 Algorithm implementation
    if (quality < 3) {
      // Incorrect or poor response - reset interval
      item.repetitions = 0;
      item.interval = 1;
    } else {
      // Correct or acceptable response
      if (item.repetitions == 0) {
        item.interval = 1;
      } else if (item.repetitions == 1) {
        item.interval = 3;
      } else {
        item.interval = (item.interval * item.easyFactor).round();
      }
      item.repetitions++;
    }

    // Update easy factor using SM-2 formula
    // EF' = EF + (5 - q) * 0.1
    item.easyFactor = (item.easyFactor + (5 - quality) * 0.1).clamp(1.3, double.infinity);

    // Calculate next review date
    item.nextReviewDate = DateTime.now().add(Duration(days: item.interval));

    items[index] = item;
    await _saveAllItems(items);
  }

  /// Remove a problem from the SRS system
  Future<void> removeProblem(String problemId) async {
    final items = _getAllItems();
    items.removeWhere((item) => item.problemId == problemId);
    await _saveAllItems(items);
  }

  /// Get statistics for the SRS system
  Map<String, dynamic> getStatistics() {
    final items = _getAllItems();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int dueCount = 0;
    int overdueCount = 0;
    double avgEasyFactor = 0;
    int totalRepetitions = 0;

    for (final item in items) {
      final reviewDate = DateTime(item.nextReviewDate.year,
          item.nextReviewDate.month, item.nextReviewDate.day);

      if (reviewDate.isBefore(todayDate)) {
        overdueCount++;
      } else if (reviewDate.isAtSameMomentAs(todayDate)) {
        dueCount++;
      }

      avgEasyFactor += item.easyFactor;
      totalRepetitions += item.repetitions;
    }

    if (items.isNotEmpty) {
      avgEasyFactor /= items.length;
    }

    return {
      'totalItems': items.length,
      'dueToday': dueCount,
      'overdue': overdueCount,
      'averageEasyFactor': double.parse(avgEasyFactor.toStringAsFixed(2)),
      'totalRepetitions': totalRepetitions,
    };
  }

  /// Clear all SRS data (for testing or reset)
  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
  }
}
