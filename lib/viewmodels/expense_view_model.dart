import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/expense_entry.dart';
import '../services/expense_cloud_store.dart';
import '../services/expense_local_store.dart';

class ExpenseViewModel extends ChangeNotifier {
  ExpenseViewModel({
    required this.cloudStore,
    required this.localStore,
  });

  final ExpenseCloudStore cloudStore;
  final ExpenseLocalStore localStore;

  static const List<String> defaultCategories = [
    'Sand',
    'Gravel',
    'Bricks',
    'Steel',
    'Cement',
    'Labour',
    'Electrical',
    'Plumbing',
  ];

  List<String> _categories = List.from(defaultCategories);
  List<String> _sites = [];
  final List<ExpenseEntry> _entries = [];

  int _selectedIndex = 0;
  bool _loading = true;

  String? _filterCategory;
  String? _filterSite;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  List<String> get categories => _categories;
  List<String> get sites => _sites;
  List<ExpenseEntry> get entries => _entries;
  int get selectedIndex => _selectedIndex;
  bool get loading => _loading;

  String? get filterCategory => _filterCategory;
  String? get filterSite => _filterSite;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;

  int get totalAmount => _entries.fold(0, (total, e) => total + e.amount);

  int get todayAmount {
    final today = DateTime.now();
    return _entries
        .where(
          (e) =>
              e.date.year == today.year &&
              e.date.month == today.month &&
              e.date.day == today.day,
        )
        .fold(0, (total, e) => total + e.amount);
  }

  List<ExpenseEntry> get todayEntries {
    final today = DateTime.now();
    return _entries
        .where(
          (e) =>
              e.date.year == today.year &&
              e.date.month == today.month &&
              e.date.day == today.day,
        )
        .toList();
  }

  Map<String, int> get siteTotals {
    final totals = <String, int>{};
    for (final entry in _entries) {
      final siteName = entry.site.trim().isEmpty
          ? 'Unknown Site'
          : entry.site.trim();
      totals.update(
        siteName,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return totals;
  }

  int get totalSites => siteTotals.length;

  List<ExpenseEntry> get filteredEntries {
    return _entries.where((e) {
      final matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      final matchesSite = _filterSite == null || e.site == _filterSite;
      var matchesDate = true;

      if (_filterStartDate != null) {
        matchesDate =
            matchesDate &&
            e.date.isAfter(_filterStartDate!.subtract(const Duration(days: 1)));
      }
      if (_filterEndDate != null) {
        matchesDate =
            matchesDate &&
            e.date.isBefore(_filterEndDate!.add(const Duration(days: 1)));
      }

      return matchesCategory && matchesSite && matchesDate;
    }).toList();
  }

  int get filteredTotal =>
      filteredEntries.fold(0, (total, e) => total + e.amount);

  List<String> get availableSites {
    final categoryEntries = _filterCategory == null
        ? _entries
        : _entries.where((e) => e.category == _filterCategory).toList();
    final allSites = <String>{};

    for (final site in _sites) {
      if (site.isNotEmpty) {
        allSites.add(site);
      }
    }
    for (final entry in categoryEntries) {
      if (entry.site.isNotEmpty) {
        allSites.add(entry.site);
      }
    }

    final sorted = allSites.toList();
    sorted.sort();
    return sorted;
  }

  Future<String?> initialize() async {
    final localSnapshot = await localStore.load(defaultCategories: defaultCategories);

    _categories = localSnapshot.categories;
    _sites = localSnapshot.sites;
    _entries
      ..clear()
      ..addAll(localSnapshot.entries);
    _loading = false;
    notifyListeners();

    if (!cloudStore.isEnabled) return null;

    try {
      final cloudSnapshot = await cloudStore.loadSnapshot();

      if (cloudSnapshot == null) {
        if (_entries.isNotEmpty || localSnapshot.hasCustomCategories) {
          await cloudStore.saveSnapshot(
            categories: _categories,
            sites: _sites,
            entries: _entries,
          );
        }
        return null;
      }

      _entries
        ..clear()
        ..addAll(cloudSnapshot.entries);
      _categories = cloudSnapshot.categories.isEmpty
          ? List<String>.from(defaultCategories)
          : cloudSnapshot.categories;
      _sites = cloudSnapshot.sites.isEmpty
          ? _deriveSitesFromEntries(cloudSnapshot.entries)
          : cloudSnapshot.sites;

      await _saveLocalData();
      notifyListeners();
      return null;
    } catch (error) {
      debugPrint('Firebase load sync failed: $error');
      return 'Cloud sync unavailable: ${cloudStore.friendlyCloudError(error)}. Using local data.';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!cloudStore.isConfigured) {
      return 'Firebase config missing: ${cloudStore.missingRunValues.join(', ')}';
    }

    try {
      final signedIn = await cloudStore.signInWithGoogle();
      if (!signedIn) {
        return 'Google sign-in was cancelled.';
      }

      await initialize();
      return null;
    } catch (error) {
      final raw = cloudStore.compactError(error);
      return 'Google sign-in failed: ${cloudStore.friendlyCloudError(error)} ($raw)';
    }
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!cloudStore.isConfigured) {
      return 'Firebase config missing: ${cloudStore.missingRunValues.join(', ')}';
    }

    try {
      await cloudStore.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final loadMessage = await initialize();
      if (loadMessage != null) {
        return loadMessage;
      }

      return null;
    } catch (error) {
      return cloudStore.friendlyCloudError(error);
    }
  }

  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!cloudStore.isConfigured) {
      return 'Firebase config missing: ${cloudStore.missingRunValues.join(', ')}';
    }

    try {
      await cloudStore.createUserWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
      );

      final loadMessage = await initialize();
      if (loadMessage != null) {
        return loadMessage;
      }

      return null;
    } catch (error) {
      return cloudStore.friendlyCloudError(error);
    }
  }

  Future<String?> signOutGoogle() async {
    try {
      await cloudStore.signOut();
      await initialize();
      return 'Signed out. Using local data only.';
    } catch (error) {
      return 'Sign-out failed: ${cloudStore.friendlyCloudError(error)}';
    }
  }

  Future<String?> addExpense(ExpenseEntry entry) async {
    _entries.insert(0, entry);
    notifyListeners();
    return _persistData();
  }

  Future<String?> updateExpense(ExpenseEntry updated) async {
    final idx = _entries.indexWhere((entry) => entry.id == updated.id);
    if (idx != -1) {
      _entries[idx] = updated;
      notifyListeners();
    }
    return _persistData();
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    _categories = [..._categories, trimmed];
    notifyListeners();
    await _persistData();
  }

  Future<void> deleteCategory(String name) async {
    _categories = _categories.where((category) => category != name).toList();
    notifyListeners();
    await _persistData();
  }

  Future<void> addSite(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_sites.any((site) => site.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    _sites = [..._sites, trimmed];
    notifyListeners();
    await _persistData();
  }

  Future<void> deleteSite(String name) async {
    _sites = _sites.where((site) => site != name).toList();
    notifyListeners();
    await _persistData();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setFilterCategory(String? value) {
    _filterCategory = value;
    _filterSite = null;
    notifyListeners();
  }

  void setFilterSite(String? value) {
    _filterSite = value;
    notifyListeners();
  }

  void setFilterStartDate(DateTime? value) {
    _filterStartDate = value;
    notifyListeners();
  }

  void setFilterEndDate(DateTime? value) {
    _filterEndDate = value;
    notifyListeners();
  }

  void clearFilters() {
    _filterCategory = null;
    _filterSite = null;
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  String buildReportText() {
    final buffer = StringBuffer();
    buffer.writeln('CONSTRUCTION EXPENSE REPORT');
    buffer.writeln('====================================');
    buffer.writeln('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buffer.writeln('');

    if (_filterCategory != null) {
      buffer.writeln('Category: $_filterCategory');
    }
    if (_filterStartDate != null && _filterEndDate != null) {
      buffer.writeln(
        'Period: ${DateFormat('dd/MM/yyyy').format(_filterStartDate!)} to ${DateFormat('dd/MM/yyyy').format(_filterEndDate!)}',
      );
    }

    buffer.writeln('');
    buffer.writeln('Total Expense: ₹$filteredTotal');
    buffer.writeln('');
    buffer.writeln('BREAKDOWN:');
    buffer.writeln('');

    for (final entry in filteredEntries) {
      buffer.writeln(
        '${entry.category} (${entry.site}): ₹${entry.amount} - ${entry.description}',
      );
      buffer.writeln('Date: ${entry.formattedDate}');
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  Future<void> _saveLocalData() {
    return localStore.save(
      categories: _categories,
      sites: _sites,
      entries: _entries,
    );
  }

  Future<String?> _persistData() async {
    await _saveLocalData();
    if (!cloudStore.isEnabled) return null;

    try {
      await cloudStore.saveSnapshot(
        categories: _categories,
        sites: _sites,
        entries: _entries,
      );
      return null;
    } catch (error) {
      debugPrint('Firebase save sync failed: $error');
      return 'Saved locally. Cloud sync failed: ${cloudStore.friendlyCloudError(error)}';
    }
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
