import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloudStore = await ExpenseCloudStore.create();
  runApp(ExpenseTrackerApp(cloudStore: cloudStore));
}

class CloudSnapshot {
  const CloudSnapshot({
    required this.categories,
    required this.sites,
    required this.entries,
  });

  final List<String> categories;
  final List<String> sites;
  final List<ExpenseEntry> entries;
}

class ExpenseCloudStore {
  ExpenseCloudStore._(
    this._firestore,
    this._auth,
    this._googleSignIn, {
    this.missingRunValues = const [],
  });

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final GoogleSignIn? _googleSignIn;
  final List<String> missingRunValues;

  static const String _collection = 'expense_app_data';
  static const String _docId = 'construction_state';

  bool get isConfigured => _firestore != null && _auth != null;
  bool get isEnabled => isConfigured && _auth?.currentUser != null;
  String? get signedInEmail => _auth?.currentUser?.email;

  static Future<ExpenseCloudStore> create() async {
    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
    final appId = const String.fromEnvironment('FIREBASE_APP_ID');
    final messagingSenderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    final authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    final storageBucket = const String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
    );
    final iosBundleId = const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    final webClientId = const String.fromEnvironment('FIREBASE_WEB_CLIENT_ID');
    final iosClientId = const String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');

    final missingValues = <String>[];
    if (apiKey.isEmpty || apiKey == 'YOUR_FIREBASE_API_KEY') {
      missingValues.add('FIREBASE_API_KEY');
    }
    if (appId.isEmpty || appId == 'YOUR_FIREBASE_APP_ID') {
      missingValues.add('FIREBASE_APP_ID');
    }
    if (messagingSenderId.isEmpty ||
        messagingSenderId == 'YOUR_FIREBASE_MESSAGING_SENDER_ID') {
      missingValues.add('FIREBASE_MESSAGING_SENDER_ID');
    }
    if (projectId.isEmpty || projectId == 'YOUR_FIREBASE_PROJECT_ID') {
      missingValues.add('FIREBASE_PROJECT_ID');
    }
    if (!kIsWeb &&
        (webClientId.isEmpty || webClientId == 'YOUR_FIREBASE_WEB_CLIENT_ID')) {
      missingValues.add('FIREBASE_WEB_CLIENT_ID');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (appId.contains(':android:')) {
        missingValues.add('FIREBASE_APP_ID (must be iOS app id on iPhone)');
      }
      if (iosClientId.isEmpty || iosClientId == 'YOUR_FIREBASE_IOS_CLIENT_ID') {
        missingValues.add('FIREBASE_IOS_CLIENT_ID');
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (appId.contains(':ios:')) {
        missingValues.add('FIREBASE_APP_ID (must be Android app id on Android)');
      }
    }
    if (missingValues.isNotEmpty) {
      debugPrint(
        'Firebase cloud disabled: missing ${missingValues.join(', ')}',
      );
      return ExpenseCloudStore._(
        null,
        null,
        null,
        missingRunValues: missingValues,
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: authDomain.isEmpty ? null : authDomain,
            storageBucket: storageBucket.isEmpty ? null : storageBucket,
            iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
          ),
        );
      }

      final auth = FirebaseAuth.instance;
      GoogleSignIn? googleSignIn;
      if (!kIsWeb) {
        final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS;
        googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(
          clientId: isApplePlatform && iosClientId.isNotEmpty
              ? iosClientId
              : null,
          serverClientId: webClientId.isEmpty ? null : webClientId,
        );
      }

      return ExpenseCloudStore._(
        FirebaseFirestore.instance,
        auth,
        googleSignIn,
      );
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
      return ExpenseCloudStore._(null, null, null);
    }
  }

  Future<bool> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) return false;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await auth.signInWithPopup(provider);
      return auth.currentUser != null;
    }

    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) return false;

    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return false;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await auth.signInWithCredential(credential);
    return auth.currentUser != null;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (error) {
      debugPrint('GoogleSignIn signOut failed: $error');
    }

    try {
      await _auth?.signOut();
    } catch (error) {
      debugPrint('FirebaseAuth signOut failed: $error');
    }
  }

  Future<CloudSnapshot?> loadSnapshot() async {
    final firestore = _firestore;
    final auth = _auth;
    if (firestore == null || auth == null) return null;

    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await firestore
        .collection(_collection)
        .doc(uid)
        .collection('state')
        .doc(_docId)
        .get();

    if (!doc.exists) return null;

    final result = doc.data() ?? <String, dynamic>{};
    final rawCategories = result['categories'];
    final rawSites = result['sites'];
    final rawExpenses = result['expenses'];

    final categories = rawCategories is List<dynamic>
        ? rawCategories.map((item) => item.toString()).toList()
        : <String>[];

    final sites = rawSites is List<dynamic>
        ? rawSites.map((item) => item.toString()).toList()
        : <String>[];

    final entries = rawExpenses is List<dynamic>
        ? rawExpenses
              .whereType<Map>()
              .map(
                (item) =>
                    ExpenseEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ExpenseEntry>[];

    return CloudSnapshot(
      categories: categories,
      sites: sites,
      entries: entries,
    );
  }

  Future<void> saveSnapshot({
    required List<String> categories,
    required List<String> sites,
    required List<ExpenseEntry> entries,
  }) async {
    final firestore = _firestore;
    final auth = _auth;
    if (firestore == null || auth == null) return;

    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    await firestore
        .collection(_collection)
        .doc(uid)
        .collection('state')
        .doc(_docId)
        .set({
          'categories': categories,
          'sites': sites,
          'expenses': entries.map((entry) => entry.toJson()).toList(),
          'updated_at': FieldValue.serverTimestamp(),
        });
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key, required this.cloudStore});

  final ExpenseCloudStore cloudStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Construction Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E8E7D)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8F7),
      ),
      home: ExpenseHomePage(cloudStore: cloudStore),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key, required this.cloudStore});

  final ExpenseCloudStore cloudStore;

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  static const List<String> _defaultCategories = [
    'Sand',
    'Gravel',
    'Bricks',
    'Steel',
    'Cement',
    'Labour',
    'Electrical',
    'Plumbing',
  ];

  List<String> _categories = List.from(_defaultCategories);
  List<String> _sites = [];
  final List<ExpenseEntry> _entries = [];
  int _selectedIndex = 0;
  bool _loading = true;

  // Report filters
  String? _filterCategory;
  String? _filterSite;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomCategories =
        (prefs.getString('construction_categories') ?? '').isNotEmpty;
    final hasCustomSites =
        (prefs.getString('construction_sites') ?? '').isNotEmpty;

    final localCategories = hasCustomCategories
        ? (jsonDecode(prefs.getString('construction_categories')!)
                  as List<dynamic>)
              .cast<String>()
        : List<String>.from(_defaultCategories);

    final rawExpenses = prefs.getString('construction_expenses');
    final localEntries = rawExpenses == null
        ? <ExpenseEntry>[]
        : (jsonDecode(rawExpenses) as List<dynamic>)
              .map(
                (item) => ExpenseEntry.fromJson(item as Map<String, dynamic>),
              )
              .toList();

    final localSites = hasCustomSites
        ? (jsonDecode(prefs.getString('construction_sites')!) as List<dynamic>)
              .cast<String>()
        : _deriveSitesFromEntries(localEntries);

    setState(() {
      _categories = localCategories;
      _sites = localSites;
      _entries
        ..clear()
        ..addAll(localEntries);
      _loading = false;
    });

    if (!widget.cloudStore.isEnabled) return;

    try {
      final cloudSnapshot = await widget.cloudStore.loadSnapshot();

      if (cloudSnapshot == null) {
        // Seed cloud data from local storage on first sync.
        if (localEntries.isNotEmpty || hasCustomCategories) {
          await widget.cloudStore.saveSnapshot(
            categories: localCategories,
            sites: localSites,
            entries: localEntries,
          );
        }
        return;
      }

      setState(() {
        _entries.clear();
        _entries.addAll(cloudSnapshot.entries);
        _categories = cloudSnapshot.categories.isEmpty
            ? List<String>.from(_defaultCategories)
            : cloudSnapshot.categories;
        _sites = cloudSnapshot.sites.isEmpty
            ? _deriveSitesFromEntries(cloudSnapshot.entries)
            : cloudSnapshot.sites;
      });

      await _saveLocalData();
    } catch (error) {
      final message = _friendlyCloudError(error);
      debugPrint('Firebase load sync failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud sync unavailable: $message. Using local data.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'construction_expenses',
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('construction_categories', jsonEncode(_categories));
    await prefs.setString('construction_sites', jsonEncode(_sites));
  }

  Future<void> _persistData() async {
    await _saveLocalData();
    if (!widget.cloudStore.isEnabled) return;

    try {
      await widget.cloudStore.saveSnapshot(
        categories: _categories,
        sites: _sites,
        entries: _entries,
      );
    } catch (error) {
      final message = _friendlyCloudError(error);
      debugPrint('Firebase save sync failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved locally. Cloud sync failed: $message'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!widget.cloudStore.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase config missing: ${widget.cloudStore.missingRunValues.join(', ')}',
          ),
        ),
      );
      return;
    }

    try {
      final signedIn = await widget.cloudStore.signInWithGoogle();
      if (!signedIn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
        return;
      }

      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced with ${widget.cloudStore.signedInEmail ?? 'your Google account'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${_friendlyCloudError(error)}'),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignOut() async {
    try {
      await widget.cloudStore.signOut();
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out. Using local data only.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-out failed: ${_friendlyCloudError(error)}'),
        ),
      );
    }
  }

  String _friendlyCloudError(Object error) {
    final text = error.toString();
    if (text.contains('canceled') || text.contains('cancelled')) {
      return 'sign-in cancelled';
    }
    if (text.contains('auth/operation-not-allowed')) {
      return 'Google provider is not enabled in Firebase Authentication';
    }
    if (text.contains('auth/unauthorized-domain')) {
      return 'web domain is not authorized in Firebase Authentication settings';
    }
    if (text.contains('auth/invalid-credential')) {
      return 'Google credential rejected; verify Android SHA keys and OAuth client setup';
    }
    if (text.contains('DEVELOPER_ERROR') || text.contains('ApiException: 10')) {
      return 'Google Sign-In configuration mismatch; add Android SHA-1/SHA-256 in Firebase';
    }
    if (text.contains('missing support for the following URL schemes') ||
        text.contains('Your app is missing support for the following URL schemes')) {
      return 'iOS URL scheme missing. Add REVERSED_CLIENT_ID under CFBundleURLTypes in ios/Runner/Info.plist';
    }
    if (text.contains('No active configuration') ||
        text.contains('clientID') ||
        text.contains('GIDClientID')) {
      return 'Google Sign-In client ID missing on iOS. Pass FIREBASE_IOS_CLIENT_ID and verify Info.plist Google Sign-In keys';
    }
    if (text.contains('network_error')) {
      return 'Google Sign-In network error';
    }
    if (text.contains('API key not valid') ||
        text.contains('auth/invalid-api-key')) {
      return 'invalid Firebase API key';
    }
    if (text.contains('permission-denied')) {
      return 'Firestore rules blocked access';
    }
    if (text.contains('not-found')) {
      return 'Firestore document path missing';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'network unavailable';
    }
    return 'check Firebase --dart-define values and platform-specific Google Sign-In setup';
  }

  void _addExpense(ExpenseEntry entry) {
    setState(() => _entries.insert(0, entry));
    _persistData();
  }

  void _updateExpense(ExpenseEntry updated) {
    setState(() {
      final idx = _entries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) _entries[idx] = updated;
    });
    _persistData();
  }

  void _addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    setState(() => _categories.add(trimmed));
    _persistData();
  }

  void _addSite(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_sites.any((s) => s.toLowerCase() == trimmed.toLowerCase())) return;
    setState(() => _sites.add(trimmed));
    _persistData();
  }

  void _deleteCategory(String name) {
    setState(() => _categories.remove(name));
    _persistData();
  }

  void _deleteSite(String name) {
    setState(() => _sites.remove(name));
    _persistData();
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

  int get _totalAmount => _entries.fold(0, (total, e) => total + e.amount);

  int get _todayAmount {
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

  List<ExpenseEntry> get _todayEntries {
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

  Map<String, int> get _siteTotals {
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

  int get _totalSites => _siteTotals.length;

  List<ExpenseEntry> get _filteredEntries {
    return _entries.where((e) {
      bool matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      bool matchesSite = _filterSite == null || e.site == _filterSite;
      bool matchesDate = true;

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

  int get _filteredTotal =>
      _filteredEntries.fold(0, (total, e) => total + e.amount);

  List<String> get _availableSites {
    final categoryEntries = _filterCategory == null
        ? _entries
        : _entries.where((e) => e.category == _filterCategory).toList();
    final sites = <String>{};
    for (final site in _sites) {
      if (site.isNotEmpty) {
        sites.add(site);
      }
    }
    for (final e in categoryEntries) {
      if (e.site.isNotEmpty) {
        sites.add(e.site);
      }
    }
    return sites.toList()..sort();
  }

  void _showAddExpenseDialog() {
    if (_sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one site first using Manage Sites.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ExpenseDialog(
        categories: _categories,
        sites: _sites,
        onSave: _addExpense,
      ),
    );
  }

  void _showEditExpenseDialog(ExpenseEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => ExpenseDialog(
        categories: _categories,
        sites: _sites,
        existingEntry: entry,
        onSave: (updated) => _updateExpense(updated),
      ),
    );
  }

  void _showManageCategoriesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ManageCategoriesDialog(
        categories: _categories,
        onAdd: _addCategory,
        onDelete: _deleteCategory,
      ),
    );
  }

  void _showManageSitesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ManageSitesDialog(
        sites: _sites,
        onAdd: _addSite,
        onDelete: _deleteSite,
      ),
    );
  }

  void _printReport() {
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
    buffer.writeln('Total Expense: ₹$_filteredTotal');
    buffer.writeln('');
    buffer.writeln('BREAKDOWN:');
    buffer.writeln('');

    for (final entry in _filteredEntries) {
      buffer.writeln(
        '${entry.category} (${entry.site}): ₹${entry.amount} - ${entry.description}',
      );
      buffer.writeln('Date: ${entry.formattedDate}');
      buffer.writeln('---');
    }

    Share.share(buffer.toString(), subject: 'Construction Expense Report');
  }

  Widget _buildDashboardPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F8F4), Color(0xFFF7F4EC)],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0EA5A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x330F766E),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expenditure',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE7FBF8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹$_totalAmount',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_entries.length} payments recorded',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD8F8F3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    if (compact) {
                      return Column(
                        children: [
                          _DashboardMiniStatCard(
                            title: 'Active Sites',
                            value: '$_totalSites',
                            icon: Icons.location_city,
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 10),
                          _DashboardMiniStatCard(
                            title: 'Today',
                            value: '₹$_todayAmount',
                            icon: Icons.today,
                            color: const Color(0xFFDC2626),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _DashboardMiniStatCard(
                            title: 'Active Sites',
                            value: '$_totalSites',
                            icon: Icons.location_city,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DashboardMiniStatCard(
                            title: 'Today',
                            value: '₹$_todayAmount',
                            icon: Icons.today,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              _FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sunny, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text(
                              "Today's Expenses",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_todayEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'No expenses today',
                              style: TextStyle(color: Colors.black45),
                            ),
                          )
                        else ...[
                          Text(
                            'Total: ₹$_todayAmount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_todayEntries.length, (index) {
                            final entry = _todayEntries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${entry.category} (${entry.site})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (entry.description.isNotEmpty)
                                          Text(
                                            entry.description,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${entry.amount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Color(0xFF0F766E),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Expenses By Site',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No expense data available for site chart.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          SiteExpenseChart(siteTotals: _siteTotals),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14000000)),
              ),
              child: _entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No expenses recorded yet. Use Add Expense above.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ListTile(
                          leading: CategoryIcon(category: entry.category),
                          title: Text(
                            '${entry.category} (${entry.site})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.description.isNotEmpty)
                                Text(
                                  entry.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                entry.formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${entry.amount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                tooltip: 'Edit',
                                onPressed: () => _showEditExpenseDialog(entry),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _filterCategory,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _filterCategory = v;
                        _filterSite =
                            null; // Reset site filter when category changes
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _filterSite,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Sites'),
                        ),
                        ..._availableSites.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterSite = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _filterStartDate == null
                          ? 'From'
                          : DateFormat('dd/MM').format(_filterStartDate!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _filterStartDate = picked);
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _filterEndDate == null
                          ? 'To'
                          : DateFormat('dd/MM').format(_filterEndDate!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _filterEndDate = picked);
                      }
                    },
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _filterCategory = null;
                        _filterSite = null;
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Summary',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹$_filteredTotal',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_filteredEntries.length} entries found',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        if (_filterCategory != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Category: $_filterCategory',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_filterSite != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Site: $_filterSite',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_filteredEntries.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No expenses match your filters. Adjust and try again.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredEntries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CategoryIcon(category: entry.category),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.category} (${entry.site})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (entry.description.isNotEmpty)
                                        Text(
                                          entry.description,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      Text(
                                        entry.formattedDate,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${entry.amount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardPage(),
      _buildExpensesPage(),
      _buildReportsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Construction Expense Tracker'),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF0F766E), Color(0xFF155E75)],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Icon(
              widget.cloudStore.isEnabled
                  ? Icons.cloud_done
                  : (widget.cloudStore.isConfigured
                        ? Icons.cloud_queue
                        : Icons.cloud_off),
              size: 20,
              color: const Color(0xFFD8F8F3),
            ),
          ),
          IconButton(
            icon: Icon(
              widget.cloudStore.isEnabled ? Icons.logout : Icons.login,
            ),
            tooltip: widget.cloudStore.isEnabled
                ? 'Sign out Google'
                : 'Sign in Google',
            onPressed: widget.cloudStore.isEnabled
                ? _handleGoogleSignOut
                : _handleGoogleSignIn,
          ),
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print report',
              onPressed: _printReport,
            ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Manage categories',
            onPressed: _showManageCategoriesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            tooltip: 'Manage sites',
            onPressed: _showManageSitesDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.cloudStore.isConfigured)
            MaterialBanner(
              backgroundColor: const Color(0xFFFFF3CD),
              content: Text(
                'Firebase config missing: ${widget.cloudStore.missingRunValues.join(', ')}',
                style: const TextStyle(color: Color(0xFF7A5C00)),
              ),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      floatingActionButton: null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

// ── Expense Entry Model ──────────────────────────────────────────────────────

class ExpenseEntry {
  ExpenseEntry({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.site,
    required this.date,
  });

  final String id;
  final String category;
  final int amount;
  final String description;
  final String site;
  final DateTime date;

  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'amount': amount,
    'description': description,
    'site': site,
    'date': date.toIso8601String(),
  };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is int
        ? rawAmount
        : rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final rawDate = json['date']?.toString();
    final parsedDate = rawDate == null
        ? DateTime.now()
        : DateTime.tryParse(rawDate) ?? DateTime.now();

    return ExpenseEntry(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      category: json['category']?.toString() ?? '',
      amount: amount,
      description: json['description']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      date: parsedDate,
    );
  }

  ExpenseEntry copyWith({
    String? category,
    int? amount,
    String? description,
    String? site,
  }) => ExpenseEntry(
    id: id,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    site: site ?? this.site,
    date: date,
  );
}

// ── Add / Edit Expense Dialog ────────────────────────────────────────────────

class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({
    super.key,
    required this.categories,
    required this.sites,
    required this.onSave,
    this.existingEntry,
  });

  final List<String> categories;
  final List<String> sites;
  final ValueChanged<ExpenseEntry> onSave;
  final ExpenseEntry? existingEntry;

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _selectedCategory;
  late String _selectedSite;

  bool get _isEdit => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _amountController = TextEditingController(
      text: existing != null ? '${existing.amount}' : '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final existingCategory = existing?.category.trim() ?? '';
    final hasExistingCategory = existingCategory.isNotEmpty &&
      widget.categories.contains(existingCategory);
    _selectedCategory = hasExistingCategory
      ? existingCategory
      : (widget.categories.isNotEmpty ? widget.categories.first : '');
    final existingSite = existing?.site.trim() ?? '';
    final hasExistingSite =
      existingSite.isNotEmpty && widget.sites.contains(existingSite);
    _selectedSite = hasExistingSite
        ? existingSite
        : (widget.sites.isNotEmpty ? widget.sites.first : '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount greater than zero.'),
        ),
      );
      return;
    }

    if (_selectedSite.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a site.')));
      return;
    }

    final entry = _isEdit
        ? widget.existingEntry!.copyWith(
            category: _selectedCategory,
            amount: amount,
            description: _descriptionController.text.trim(),
            site: _selectedSite.trim(),
          )
        : ExpenseEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            category: _selectedCategory,
            amount: amount,
            description: _descriptionController.text.trim(),
            site: _selectedSite.trim(),
            date: DateTime.now(),
          );

    widget.onSave(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryValue = widget.categories.contains(_selectedCategory)
        ? _selectedCategory
        : null;
    final selectedSiteValue = widget.sites.contains(_selectedSite)
        ? _selectedSite
        : null;

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedCategoryValue,
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
              decoration: const InputDecoration(
                labelText: 'Payment type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSiteValue,
              items: widget.sites
                  .map(
                    (site) => DropdownMenuItem(value: site, child: Text(site)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSite = v);
              },
              decoration: const InputDecoration(
                labelText: 'Site',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}

// ── Manage Categories Dialog ─────────────────────────────────────────────────

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({
    super.key,
    required this.categories,
    required this.onAdd,
    required this.onDelete,
  });

  final List<String> categories;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final TextEditingController _newCatController = TextEditingController();
  late List<String> _localCategories;

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  @override
  void dispose() {
    _newCatController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newCatController.text.trim();
    if (name.isEmpty) return;
    if (_localCategories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category already exists.')));
      return;
    }
    widget.onAdd(name);
    setState(() {
      _localCategories.add(name);
      _newCatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCatController,
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _localCategories.length,
                itemBuilder: (context, index) {
                  final cat = _localCategories[index];
                  return ListTile(
                    leading: CategoryIcon(category: cat),
                    title: Text(cat),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        widget.onDelete(cat);
                        setState(() => _localCategories.remove(cat));
                      },
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class ManageSitesDialog extends StatefulWidget {
  const ManageSitesDialog({
    super.key,
    required this.sites,
    required this.onAdd,
    required this.onDelete,
  });

  final List<String> sites;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  @override
  State<ManageSitesDialog> createState() => _ManageSitesDialogState();
}

class _ManageSitesDialogState extends State<ManageSitesDialog> {
  final TextEditingController _newSiteController = TextEditingController();
  late List<String> _localSites;

  @override
  void initState() {
    super.initState();
    _localSites = List.from(widget.sites);
  }

  @override
  void dispose() {
    _newSiteController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newSiteController.text.trim();
    if (name.isEmpty) return;
    if (_localSites.any((s) => s.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Site already exists.')));
      return;
    }
    widget.onAdd(name);
    setState(() {
      _localSites.add(name);
      _newSiteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Sites'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSiteController,
                    decoration: const InputDecoration(
                      labelText: 'New site name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _localSites.length,
                itemBuilder: (context, index) {
                  final site = _localSites[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(site),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        widget.onDelete(site);
                        setState(() => _localSites.remove(site));
                      },
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ── Category Icon ────────────────────────────────────────────────────────────

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.orange.shade100,
      child: Icon(
        _iconForCategory(category),
        color: Colors.orange.shade900,
        size: 20,
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sand':
        return Icons.landscape;
      case 'gravel':
        return Icons.grass;
      case 'bricks':
        return Icons.dns;
      case 'steel':
        return Icons.build;
      case 'cement':
        return Icons.format_paint;
      case 'labour':
        return Icons.groups;
      case 'electrical':
        return Icons.electrical_services;
      case 'plumbing':
        return Icons.plumbing;
      default:
        return Icons.category;
    }
  }
}

class _DashboardMiniStatCard extends StatelessWidget {
  const _DashboardMiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const baseMs = 420;
    final totalMs = baseMs + delay.inMilliseconds;
    final delayedStart = totalMs == 0 ? 0.0 : delay.inMilliseconds / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      child: child,
      builder: (context, rawValue, builtChild) {
        final curvedValue = rawValue <= delayedStart
            ? 0.0
            : Curves.easeOutCubic.transform(
                (rawValue - delayedStart) / (1 - delayedStart),
              );
        final shifted = 20 * (1 - curvedValue);
        return Opacity(
          opacity: curvedValue,
          child: Transform.translate(
            offset: Offset(0, shifted),
            child: builtChild,
          ),
        );
      },
    );
  }
}

class SiteExpenseChart extends StatelessWidget {
  const SiteExpenseChart({super.key, required this.siteTotals});

  final Map<String, int> siteTotals;

  @override
  Widget build(BuildContext context) {
    final sorted = siteTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = sorted.first.value;
    const palette = <Color>[
      Color(0xFF0EA5A1),
      Color(0xFF2563EB),
      Color(0xFFF97316),
      Color(0xFF7C3AED),
      Color(0xFFDC2626),
      Color(0xFF16A34A),
    ];

    return Column(
      children: List.generate(sorted.length, (index) {
        final entry = sorted[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _SiteBarRow(
            siteName: entry.key,
            amount: entry.value,
            maxAmount: highest,
            barColor: palette[index % palette.length],
          ),
        );
      }),
    );
  }
}

class _SiteBarRow extends StatelessWidget {
  const _SiteBarRow({
    required this.siteName,
    required this.amount,
    required this.maxAmount,
    required this.barColor,
  });

  final String siteName;
  final int amount;
  final int maxAmount;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount <= 0 ? 0.0 : amount / maxAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                siteName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹$amount',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * ratio.clamp(0.0, 1.0);
              return Stack(
                children: [
                  Container(
                    height: 12,
                    color: barColor.withValues(alpha: 0.18),
                  ),
                  Container(
                    height: 12,
                    width: width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.78), barColor],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
