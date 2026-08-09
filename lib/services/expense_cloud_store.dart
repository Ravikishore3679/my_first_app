import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/cloud_snapshot.dart';
import '../models/expense_entry.dart';

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
  String? get currentUserId => _auth?.currentUser?.uid;

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
      debugPrint('Firebase cloud disabled: missing ${missingValues.join(', ')}');
      return ExpenseCloudStore._(
        null,
        null,
        null,
        missingRunValues: missingValues,
      );
    }

    final resolvedAuthDomain =
        authDomain.isEmpty && kIsWeb ? '$projectId.firebaseapp.com' : authDomain;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: resolvedAuthDomain.isEmpty ? null : resolvedAuthDomain,
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
          clientId: isApplePlatform && iosClientId.isNotEmpty ? iosClientId : null,
          serverClientId: webClientId.isEmpty ? null : webClientId,
        );
      }

      return ExpenseCloudStore._(FirebaseFirestore.instance, auth, googleSignIn);
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

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase authentication is not configured');
    }

    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createUserWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase authentication is not configured');
    }

    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmedName);
      await credential.user?.reload();
    }
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
              .map((item) => ExpenseEntry.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <ExpenseEntry>[];

    return CloudSnapshot(categories: categories, sites: sites, entries: entries);
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

  String friendlyCloudError(Object error) {
    final text = error.toString();
    final normalized = text.toLowerCase();

    if (normalized.contains('canceled') || normalized.contains('cancelled')) {
      return 'sign-in cancelled';
    }
    if (normalized.contains('auth/operation-not-allowed')) {
      return 'Email/password login is not enabled in Firebase Authentication';
    }
    if (normalized.contains('stateerror')) {
      return 'Firebase is not configured for authentication';
    }
    if (normalized.contains('auth/user-not-found')) {
      return 'No account found for this email';
    }
    if (normalized.contains('auth/wrong-password')) {
      return 'Incorrect email or password';
    }
    if (normalized.contains('auth/email-already-in-use')) {
      return 'This email is already registered';
    }
    if (normalized.contains('auth/weak-password')) {
      return 'Password is too weak (minimum 6 characters)';
    }
    if (normalized.contains('auth/invalid-email')) {
      return 'Invalid email format';
    }
    if (normalized.contains('auth/unauthorized-domain')) {
      return 'web domain is not authorized in Firebase Authentication settings';
    }
    if (normalized.contains('auth/invalid-credential')) {
      return 'Incorrect email or password';
    }
    if (normalized.contains('developer_error') ||
        normalized.contains('apiexception: 10') ||
        normalized.contains('status code: 10') ||
        normalized.contains('signinfailed') ||
        normalized.contains('clientconfigurationerror') ||
        normalized.contains('google_sign_in_failed')) {
      return 'Google Sign-In configuration mismatch; add Android SHA-1/SHA-256 in Firebase';
    }
    if (normalized.contains('missing support for the following url schemes') ||
        normalized.contains('your app is missing support for the following url schemes')) {
      return 'iOS URL scheme missing. Add REVERSED_CLIENT_ID under CFBundleURLTypes in ios/Runner/Info.plist';
    }
    if (normalized.contains('no active configuration') ||
        normalized.contains('clientid') ||
        normalized.contains('gidclientid')) {
      return 'Google Sign-In client ID missing on iOS. Pass FIREBASE_IOS_CLIENT_ID and verify Info.plist Google Sign-In keys';
    }
    if (normalized.contains('network_error') || normalized.contains('networkerror')) {
      return 'Google Sign-In network error';
    }
    if (normalized.contains('api key not valid') ||
        normalized.contains('auth/invalid-api-key')) {
      return 'invalid Firebase API key';
    }
    if (normalized.contains('permission-denied')) {
      return 'Firestore rules blocked access';
    }
    if (normalized.contains('not-found')) {
      return 'Firestore document path missing';
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
      return 'network unavailable';
    }
    return 'check Firebase --dart-define values and Authentication configuration';
  }

  String compactError(Object error) {
    if (error is PlatformException) {
      final code = error.code.isEmpty ? 'platform' : error.code;
      final message = (error.message ?? '').trim();
      return message.isEmpty ? code : '$code: $message';
    }
    if (error is FirebaseAuthException) {
      final code = error.code;
      final message = (error.message ?? '').trim();
      return message.isEmpty ? code : '$code: $message';
    }
    return error.toString();
  }
}
