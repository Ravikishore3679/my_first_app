import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_entry.dart';

class LocalSnapshot {
  const LocalSnapshot({
    required this.hasCustomCategories,
    required this.hasCustomSites,
    required this.categories,
    required this.sites,
    required this.entries,
  });

  final bool hasCustomCategories;
  final bool hasCustomSites;
  final List<String> categories;
  final List<String> sites;
  final List<ExpenseEntry> entries;
}

class ExpenseLocalStore {
  const ExpenseLocalStore();

  static const String expensesKey = 'construction_expenses';
  static const String categoriesKey = 'construction_categories';
  static const String sitesKey = 'construction_sites';

  Future<LocalSnapshot> load({required List<String> defaultCategories}) async {
    final prefs = await SharedPreferences.getInstance();

    final hasCustomCategories = (prefs.getString(categoriesKey) ?? '').isNotEmpty;
    final hasCustomSites = (prefs.getString(sitesKey) ?? '').isNotEmpty;

    final categories = hasCustomCategories
        ? (jsonDecode(prefs.getString(categoriesKey)!) as List<dynamic>).cast<String>()
        : List<String>.from(defaultCategories);

    final rawExpenses = prefs.getString(expensesKey);
    final entries = rawExpenses == null
        ? <ExpenseEntry>[]
        : (jsonDecode(rawExpenses) as List<dynamic>)
              .map((item) => ExpenseEntry.fromJson(item as Map<String, dynamic>))
              .toList();

    final sites = hasCustomSites
        ? (jsonDecode(prefs.getString(sitesKey)!) as List<dynamic>).cast<String>()
        : _deriveSitesFromEntries(entries);

    return LocalSnapshot(
      hasCustomCategories: hasCustomCategories,
      hasCustomSites: hasCustomSites,
      categories: categories,
      sites: sites,
      entries: entries,
    );
  }

  Future<void> save({
    required List<String> categories,
    required List<String> sites,
    required List<ExpenseEntry> entries,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      expensesKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(categoriesKey, jsonEncode(categories));
    await prefs.setString(sitesKey, jsonEncode(sites));
  }

  List<String> _deriveSitesFromEntries(List<ExpenseEntry> entries) {
    final seen = <String>{};
    final result = <String>[];
    for (final entry in entries) {
      final trimmed = entry.site.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        result.add(trimmed);
      }
    }
    return result;
  }
}
