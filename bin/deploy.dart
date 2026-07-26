import 'dart:io';
import 'package:yaml/yaml.dart';

//const String firebaseAppId = "YOUR_FIREBASE_ANDROID_APP_ID";
const String testerGroups = "qa-testers"; // Tester group name in Firebase Console
// ----------------------------

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print("❌ ERROR: pubspec.yaml file not found in current root working directory.");
    exit(1);
  }

  print("🔄 Reading package settings out of pubspec.yaml...");
  final pubspecContent = await pubspecFile.readAsString();
  final doc = loadYaml(pubspecContent);
  final String currentVersion = doc['version']?.toString() ?? '1.0.0+1';

  // Split version parts out (e.g. 1.0.2+5)
  final versionParts = currentVersion.split('+');
  final versionName = versionParts[0];
  final int currentBuildNumber = int.parse(versionParts[1]);
  final int nextBuildNumber = currentBuildNumber + 1;
  final String nextFullVersion = "$versionName+$nextBuildNumber";

  print("🚀 Bumping Android target version string: $currentVersion ➡️ $nextFullVersion");

  // Increment the build code dynamically inside the file string buffer
  final updatedContent = pubspecContent.replaceFirst(
    "version: $currentVersion",
    "version: $nextFullVersion",
  );
  await pubspecFile.writeAsString(updatedContent);

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

  final firebaseAppId = env['FIREBASE_APP_ID'];
  if (firebaseAppId == null || firebaseAppId.isEmpty) {
    print('❌ Error: FIREBASE_APP_ID missing from .env!');
    exit(1);
  }

  // 3. Build the Android Binary with version flags
  print('📦 Step 1: Building Android APK...');
  await runCommand('flutter', [
  'build', 'apk', 
  '--release', 
  '--split-per-abi', // ⚡ Splits the single giant APK into 3 small, optimized APKs
  '--dart-define-from-file=.env'
]);
 // Extract metadata dynamically from environment variables or use fallback strings
  final String commitSha = Platform.environment['GITHUB_SHA'] ?? 'N/A';
  final String branchName = Platform.environment['GITHUB_REF_NAME'] ?? 'master';
  final String actor = Platform.environment['GITHUB_ACTOR'] ?? 'Automated Script';
  final String currentTime = DateTime.now().toUtc().toIso8601String();

  // Create the formatted release notes string exactly matching your visual layout
  final String releaseNotes = '''
🚀 Multi-Environment Build #15

🌍 Environment: development
📱 Version: $nextFullVersion

📝 Build Type: 🔓 Development/Testing (All Environments)
🔄 Runtime Switching: Enabled (Flexibility)

📋 Action: Build and Deploy
👤 Triggered by: $actor

🔗 Commit: $commitSha
🌿 Branch: $branchName
📅 Built at: $currentTime
''';  

  print('✅ APK built successfully.');

  // 4. Deploy to Firebase App Distribution
  print('📲 Step 2: Uploading to Firebase App Distribution...');
  
 await runCommand('firebase', [
    'appdistribution:distribute',
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    '--app', firebaseAppId,
    '--groups', testerGroups,
    '--release-notes', releaseNotes 
  ]);

    print("\n✅ Deployment successful! Build version $nextFullVersion is live.");
}
Future<void> runCommand(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, runInShell: true);
  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;

 
  if (exitCode != 0) {
    print("❌ Critical breakdown: Command '$executable ${arguments.join(' ')}' exited with code $exitCode");
    exit(exitCode);
  }
}
