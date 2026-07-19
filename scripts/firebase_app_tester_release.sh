#!/usr/bin/env bash
set -euo pipefail

# Build and distribute a Flutter release to Firebase App Distribution.
# This script updates pubspec version before build so testers see the new version.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
DEFAULT_ENV_FILE="$ROOT_DIR/.env"

PLATFORM="android"
ANDROID_ARTIFACT="apk"
BUILD_NAME=""
BUILD_NUMBER=""
FIREBASE_APP_ID=""
TESTERS=""
DIST_GROUPS=""
RELEASE_NOTES=""
DART_DEFINE_FILE="$DEFAULT_ENV_FILE"
SKIP_VERSION_UPDATE="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/firebase_app_tester_release.sh [options]

Required:
  --firebase-app-id <id>          Firebase App ID for the target app

One of:
  --testers <emails>              Comma-separated tester emails
  --groups <aliases>              Comma-separated group aliases

Optional:
  --platform <android|ios>        Build target platform (default: android)
  --android-artifact <apk|aab>    Android artifact type (default: apk)
  --build-name <x.y.z>            Version name (default: from pubspec)
  --build-number <n>              Build number (default: current+1)
  --release-notes <text>          Custom release notes
  --dart-define-file <path>       Path to .env-like file (default: ./.env)
  --skip-version-update           Do not update pubspec.yaml
  -h, --help                      Show this help

Examples:
  ./scripts/firebase_app_tester_release.sh \
    --platform android \
    --firebase-app-id 1:1234567890:android:abc123 \
    --groups qa-team \
    --release-notes "Expense fix and login improvements"

  ./scripts/firebase_app_tester_release.sh \
    --platform ios \
    --firebase-app-id 1:1234567890:ios:abc123 \
    --testers user1@example.com,user2@example.com
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --android-artifact)
      ANDROID_ARTIFACT="$2"
      shift 2
      ;;
    --build-name)
      BUILD_NAME="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --firebase-app-id)
      FIREBASE_APP_ID="$2"
      shift 2
      ;;
    --testers)
      TESTERS="$2"
      shift 2
      ;;
    --groups)
      DIST_GROUPS="$2"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="$2"
      shift 2
      ;;
    --dart-define-file)
      DART_DEFINE_FILE="$2"
      shift 2
      ;;
    --skip-version-update)
      SKIP_VERSION_UPDATE="true"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$PLATFORM" != "android" && "$PLATFORM" != "ios" ]]; then
  echo "Error: --platform must be android or ios"
  exit 1
fi

if [[ "$ANDROID_ARTIFACT" != "apk" && "$ANDROID_ARTIFACT" != "aab" ]]; then
  echo "Error: --android-artifact must be apk or aab"
  exit 1
fi

if [[ -z "$FIREBASE_APP_ID" ]]; then
  echo "Error: --firebase-app-id is required"
  exit 1
fi

if [[ -z "$TESTERS" && -z "$DIST_GROUPS" ]]; then
  echo "Error: provide --testers or --groups"
  exit 1
fi

if [[ -n "$TESTERS" && -n "$DIST_GROUPS" ]]; then
  echo "Error: use either --testers or --groups, not both"
  exit 1
fi

require_cmd flutter
require_cmd firebase
require_cmd awk

if [[ ! -f "$PUBSPEC_FILE" ]]; then
  echo "Error: pubspec.yaml not found at $PUBSPEC_FILE"
  exit 1
fi

if [[ ! -f "$DART_DEFINE_FILE" ]]; then
  echo "Error: dart-define file not found at $DART_DEFINE_FILE"
  exit 1
fi

CURRENT_VERSION_LINE="$(awk '/^version: / {print $2; exit}' "$PUBSPEC_FILE")"
if [[ -z "$CURRENT_VERSION_LINE" || "$CURRENT_VERSION_LINE" != *"+"* ]]; then
  echo "Error: pubspec version must look like x.y.z+n"
  exit 1
fi

CURRENT_BUILD_NAME="${CURRENT_VERSION_LINE%%+*}"
CURRENT_BUILD_NUMBER="${CURRENT_VERSION_LINE##*+}"

if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="$CURRENT_BUILD_NAME"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  if [[ "$CURRENT_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    BUILD_NUMBER="$((CURRENT_BUILD_NUMBER + 1))"
  else
    echo "Error: current build number is not numeric: $CURRENT_BUILD_NUMBER"
    exit 1
  fi
fi

NEW_VERSION_LINE="$BUILD_NAME+$BUILD_NUMBER"

if [[ "$SKIP_VERSION_UPDATE" != "true" ]]; then
  # macOS-safe in-place update.
  awk -v version="$NEW_VERSION_LINE" '
    BEGIN { updated = 0 }
    {
      if (!updated && $1 == "version:") {
        print "version: " version
        updated = 1
      } else {
        print $0
      }
    }
  ' "$PUBSPEC_FILE" > "$PUBSPEC_FILE.tmp"

  mv "$PUBSPEC_FILE.tmp" "$PUBSPEC_FILE"
  echo "Updated pubspec version to $NEW_VERSION_LINE"
else
  echo "Skipping pubspec version update; using build flags only"
fi

if [[ -z "$RELEASE_NOTES" ]]; then
  RELEASE_NOTES="Release $BUILD_NAME ($BUILD_NUMBER)"
fi

cd "$ROOT_DIR"

echo "Running flutter pub get..."
flutter pub get

BUILD_OUTPUT=""
if [[ "$PLATFORM" == "android" ]]; then
  if [[ "$ANDROID_ARTIFACT" == "aab" ]]; then
    echo "Building Android App Bundle..."
    flutter build appbundle \
      --release \
      --build-name "$BUILD_NAME" \
      --build-number "$BUILD_NUMBER" \
      --dart-define-from-file "$DART_DEFINE_FILE"

    BUILD_OUTPUT="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
  else
    echo "Building Android APK..."
    flutter build apk \
      --release \
      --build-name "$BUILD_NAME" \
      --build-number "$BUILD_NUMBER" \
      --dart-define-from-file "$DART_DEFINE_FILE"

    BUILD_OUTPUT="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  fi
else
  echo "Building iOS IPA..."
  flutter build ipa \
    --release \
    --build-name "$BUILD_NAME" \
    --build-number "$BUILD_NUMBER" \
    --dart-define-from-file "$DART_DEFINE_FILE"

  BUILD_OUTPUT="$ROOT_DIR/build/ios/ipa/Runner.ipa"
fi

if [[ ! -f "$BUILD_OUTPUT" ]]; then
  echo "Error: build artifact not found: $BUILD_OUTPUT"
  exit 1
fi

echo "Uploading to Firebase App Distribution..."
DIST_ARGS=(
  appdistribution:distribute
  "$BUILD_OUTPUT"
  --app "$FIREBASE_APP_ID"
  --release-notes "$RELEASE_NOTES"
)

if [[ -n "$TESTERS" ]]; then
  DIST_ARGS+=(--testers "$TESTERS")
else
  DIST_ARGS+=(--groups "$DIST_GROUPS")
fi

firebase "${DIST_ARGS[@]}"

echo "Done. Uploaded $PLATFORM release $BUILD_NAME+$BUILD_NUMBER to Firebase App Distribution."
