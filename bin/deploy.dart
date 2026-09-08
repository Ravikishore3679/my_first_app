import 'dart:io';

import 'package:yaml/yaml.dart';

const String testerGroups = 'qa-testers';

Future<void> main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    stderr.writeln('❌ ERROR: pubspec.yaml file not found in current root working directory.');
    exit(1);
  }

  stdout.writeln('🔄 Reading package settings out of pubspec.yaml...');
  final pubspecContent = await pubspecFile.readAsString();
  final doc = loadYaml(pubspecContent);
  final currentVersion = doc['version']?.toString() ?? '1.0.0+1';

  final versionParts = currentVersion.split('+');
  final versionName = versionParts[0];
  final currentBuildNumber = int.parse(versionParts[1]);
  final nextBuildNumber = currentBuildNumber + 1;
  final nextFullVersion = '$versionName+$nextBuildNumber';

  stdout.writeln('🚀 Bumping Android target version string: $currentVersion ➡️ $nextFullVersion');

  final updatedContent = pubspecContent.replaceFirst(
    'version: $currentVersion',
    'version: $nextFullVersion',
  );
  await pubspecFile.writeAsString(updatedContent);

  final envFile = File('.env');
  if (!await envFile.exists()) {
    stderr.writeln('❌ Error: .env file missing!');
    exit(1);
  }

  final envLines = await envFile.readAsLines();
  final env = <String, String>{};
  for (final line in envLines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) continue;
    final parts = trimmedLine.split('=');
    if (parts.length >= 2) {
      env[parts.first.trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final firebaseAppId = env['FIREBASE_APP_ID'];
  if (firebaseAppId == null || firebaseAppId.isEmpty) {
    stderr.writeln('❌ Error: FIREBASE_APP_ID missing from .env!');
    exit(1);
  }

  stdout.writeln('📦 Step 1: Building Android APK...');
  await runCommand('flutter', [
    'build',
    'apk',
    '--release',
    '--split-per-abi',
    '--dart-define-from-file=.env',
  ]);

  final commitSha = Platform.environment['GITHUB_SHA'] ?? 'N/A';
  final branchName = Platform.environment['GITHUB_REF_NAME'] ?? 'master';
  final actor = Platform.environment['GITHUB_ACTOR'] ?? 'Automated Script';
  final currentTime = DateTime.now().toUtc().toIso8601String();

  final releaseNotes = '''
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

  stdout.writeln('✅ APK built successfully.');
  stdout.writeln('📲 Step 2: Uploading to Firebase App Distribution...');

  await runCommand('firebase', [
    'appdistribution:distribute',
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    '--app',
    firebaseAppId,
    '--groups',
    testerGroups,
    '--release-notes',
    releaseNotes,
  ]);

  stdout.writeln('\n✅ Deployment successful! Build version $nextFullVersion is live.');
}

Future<void> runCommand(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, runInShell: true);
  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln(
      "❌ Critical breakdown: Command '$executable ${arguments.join(' ')}' exited with code $exitCode",
    );
    exit(exitCode);
  }
}
