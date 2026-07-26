import 'dart:io';

void main() async {
  print('🚀 Starting Firebase App Distribution deployment...');

  // 1. Parse pubspec.yaml for the version
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print('❌ Error: pubspec.yaml file missing!');
    exit(1);
  }
  
  final pubspecLines = await pubspecFile.readAsLines();
  String appVersion = '1.0.0+1'; // fallback default
  for (var line in pubspecLines) {
    if (line.trim().startsWith('version:')) {
      appVersion = line.split('version:')[1].trim();
      break;
    }
  }
  print('📌 App Version detected: $appVersion');

  // 2. Parse the root .env file
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('❌ Error: .env file missing!');
    exit(1);
  }

  final envLines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in envLines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final firebaseAppId = env['FIREBASE_APP_ID_ANDROID'];
  if (firebaseAppId == null || firebaseAppId.isEmpty) {
    print('❌ Error: FIREBASE_APP_ID_ANDROID missing from .env!');
    exit(1);
  }

  // 3. Build the Android Binary with version flags
  print('📦 Step 1: Building Android APK...');
  final buildResult = await Process.run(
    'flutter',
    [
      'build', 'apk', 
      '--release', 
      '--dart-define-from-file=.env',
      '--dart-define=APP_VERSION=$appVersion' // Passes version to Flutter code
    ],
    runInShell: true,
  );

  if (buildResult.exitCode != 0) {
    print(buildResult.stderr);
    print('❌ Error: Flutter build failed!');
    exit(buildResult.exitCode);
  }
  print('✅ APK built successfully.');

  // 4. Deploy to Firebase App Distribution
  print('📲 Step 2: Uploading to Firebase App Distribution...');
  final apkPath = 'build/app/outputs/flutter-apk/app-release.apk';

  final process = await Process.start(
    'firebase',
    [
      'appdistribution:distribute',
      apkPath,
      '--app', firebaseAppId,
      '--groups', 'qa-testers',
      '--release-notes', 'Version $appVersion automated release.' // Injected here
    ],
    runInShell: true,
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;

  if (exitCode == 0) {
    print('🎉 Success! Version $appVersion sent to testers.');
  } else {
    print('❌ Error: Firebase upload failed!');
    exit(exitCode);
  }
}
