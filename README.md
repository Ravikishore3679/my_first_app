# my_first_app

Construction expense tracker app with local storage and optional Firebase cloud sync.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Firebase Cloud Setup

Cloud sync is enabled when you run with Firebase `--dart-define` values.

1. Create a Firebase project.
2. Enable Authentication:
	 - Go to Authentication -> Sign-in method
	 - Enable Google sign-in
	 - Add your support email and save
3. Enable Firestore Database in native mode.
4. Add temporary Firestore rules (for testing):

```txt
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /expense_app_data/{userId}/state/{docId} {
			allow read, write: if request.auth != null && request.auth.uid == userId;
		}
	}
}
```

5. Run app with your Firebase config values (from Firebase app settings):

```bash
flutter run \
	--dart-define=FIREBASE_API_KEY=AIzaSyBNwNVmsGzF8M1fe5mF4f3KBTFKMSNEv48 \
	--dart-define=FIREBASE_APP_ID=YOUR_PLATFORM_APP_ID \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=534796740132 \
	--dart-define=FIREBASE_PROJECT_ID=constructionexpensetrack-358ef \
	--dart-define=FIREBASE_WEB_CLIENT_ID=534796740132-u7ncs9cs745m7tahobkjcbrlh1qd99at.apps.googleusercontent.com
```

Platform-specific notes:
	- iPhone must use iOS App ID (contains `:ios:`), not Android App ID.
	- Android must use Android App ID (contains `:android:`).
	- iPhone Google sign-in also needs `FIREBASE_IOS_CLIENT_ID` (CLIENT_ID from GoogleService-Info.plist).

Optional defines for some platforms:

```bash
--dart-define=FIREBASE_AUTH_DOMAIN=YOUR_FIREBASE_AUTH_DOMAIN
--dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_STORAGE_BUCKET
--dart-define=FIREBASE_IOS_BUNDLE_ID=YOUR_IOS_BUNDLE_ID
--dart-define=FIREBASE_IOS_CLIENT_ID=YOUR_FIREBASE_IOS_CLIENT_ID
```

For iOS, add Google URL scheme config to ios/Runner/Info.plist:
	- Add `GIDClientID` with `CLIENT_ID` from GoogleService-Info.plist.
	- Add `CFBundleURLTypes` -> `CFBundleURLSchemes` containing `REVERSED_CLIENT_ID`.

Google sign-in setup reminders:
	- In Firebase project settings, add Android and iOS apps that match your app package/bundle IDs.
	- In Firebase Android app settings, add SHA-1 and SHA-256 keys.
	- Copy `FIREBASE_WEB_CLIENT_ID` from Firebase Console -> Authentication -> Sign-in method -> Google provider.

Without these values, the app automatically uses local storage only.

## Quick Run

Use the saved VS Code launch profile or run:

```bash
flutter run \
	--dart-define=FIREBASE_API_KEY=AIzaSyBNwNVmsGzF8M1fe5mF4f3KBTFKMSNEv48 \
	--dart-define=FIREBASE_APP_ID=YOUR_PLATFORM_APP_ID \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=534796740132 \
	--dart-define=FIREBASE_PROJECT_ID=constructionexpensetrack-358ef \
	--dart-define=FIREBASE_WEB_CLIENT_ID=534796740132-u7ncs9cs745m7tahobkjcbrlh1qd99at.apps.googleusercontent.com \
	--dart-define=FIREBASE_IOS_CLIENT_ID=YOUR_FIREBASE_IOS_CLIENT_ID
```

## Firebase App Tester Release Script

Use the release script to build and upload to Firebase App Distribution with version details.

1. Install Firebase CLI and log in:

```bash
npm install -g firebase-tools
firebase login
```

2. Make script executable:

```bash
chmod +x ./scripts/firebase_app_tester_release.sh
```

3. Run Android release (recommended):

```bash
./scripts/firebase_app_tester_release.sh \
  --platform android \
  --firebase-app-id 1:1234567890:android:abc123 \
  --groups qa-team
```

4. Optional iOS release:

```bash
./scripts/firebase_app_tester_release.sh \
  --platform ios \
  --firebase-app-id 1:1234567890:ios:abc123 \
  --testers user1@example.com,user2@example.com
```

Default behavior:
- Reads current app version from `pubspec.yaml`.
- Increments build number automatically (for example `1.0.0+1` to `1.0.0+2`).
- Writes updated version back to `pubspec.yaml`.
- Builds release artifact and uploads it to Firebase App Distribution.

Useful flags:
- `--android-artifact apk` to distribute APK (default, best for App Tester).
- `--android-artifact aab` if your project is linked to Google Play.
- `--build-name 1.2.0` to set marketing version.
- `--build-number 45` to set build number.
- `--release-notes "Fixes login and sync"` to customize release notes.
- `--skip-version-update` to build/distribute without editing `pubspec.yaml`.


optional

FIREBASE_AUTH_DOMAIN=constructionexpensetrack-358ef.firebaseapp.com
FIREBASE_STORAGE_BUCKET=constructionexpensetrack-358ef.firebasestorage.app
FIREBASE_IOS_BUNDLE_ID=com.ravi.myFirstApp
FIREBASE_IOS_CLIENT_ID=534796740132-i4ljrm4rar1dsi29pt055fdo069mmgnt.apps.googleusercontent.com
