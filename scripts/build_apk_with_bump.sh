#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

line="$(grep -E '^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' pubspec.yaml | head -n1)"
if [[ -z "$line" ]]; then
  echo "Failed to parse version from pubspec.yaml"
  exit 1
fi

version_raw="${line#version: }"
IFS='.+ ' read -r major minor patch build <<<"$version_raw"

new_patch=$((patch + 1))
new_build=$((build + 1))
new_version="${major}.${minor}.${new_patch}+${new_build}"

perl -0777 -i -pe "s/^version:\s*\d+\.\d+\.\d+\+\d+/version: ${new_version}/m" pubspec.yaml

echo "Version bumped: ${version_raw} -> ${new_version}"
flutter pub get

if ! flutter build apk; then
  echo "Release build failed, retrying after flutter clean..."
  flutter clean
  flutter pub get
  flutter build apk
fi

echo "APK ready: build/app/outputs/flutter-apk/app-release.apk"
