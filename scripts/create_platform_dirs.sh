#!/usr/bin/env bash
set -euo pipefail

# Run this after extracting the project if android/ios folders are missing.
flutter create --platforms=android,ios .
flutter pub get
flutterfire configure
