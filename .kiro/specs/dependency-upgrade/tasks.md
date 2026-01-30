# Implementation Plan: Dependency Upgrade

## Overview

This implementation plan upgrades Flutter dependencies to their latest major versions. Based on thorough research, the upgrade requires minimal code changes: 1 import addition and 3 test method renames. The main consideration is ensuring the Flutter SDK meets version requirements (3.32+/Dart 3.8+).

## Tasks

- [x] 1. Preparation and Backup
  - [x] 1.1 Verify Flutter SDK version meets requirements (3.32+/Dart 3.8+)
    - Run `flutter --version` to check current version
    - If below 3.32, run `flutter upgrade` first
    - _Requirements: SDK Requirements section_
  
  - [x] 1.2 Create backup of dependency files
    - Copy `pubspec.yaml` to `pubspec.yaml.backup`
    - Copy `pubspec.lock` to `pubspec.lock.backup`
    - _Requirements: 9.1, 9.2_

- [x] 2. Update pubspec.yaml dependencies
  - [x] 2.1 Update all package versions in pubspec.yaml
    - Update `flutter_riverpod: ^2.6.1` to `flutter_riverpod: ^3.2.0`
    - Update `flutter_local_notifications: ^18.0.1` to `flutter_local_notifications: ^20.0.0`
    - Update `tray_manager: ^0.2.0` to `tray_manager: ^0.5.2`
    - Update `window_manager: ^0.3.0` to `window_manager: ^0.5.1`
    - Update `flutter_dotenv: ^5.1.0` to `flutter_dotenv: ^6.0.0`
    - Update `intl: ^0.19.0` to `intl: ^0.20.2`
    - Update `flutter_lints: ^5.0.0` to `flutter_lints: ^6.0.0`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  
  - [x] 2.2 Run flutter pub get and resolve any dependency conflicts
    - Run `flutter pub get`
    - If conflicts occur, check error messages and adjust version constraints
    - _Requirements: 2.8_

- [x] 3. Migrate Riverpod code
  - [x] 3.1 Add legacy import for StateProvider in providers.dart
    - Add `import 'package:flutter_riverpod/legacy.dart';` after the main flutter_riverpod import
    - This enables continued use of StateProvider (selectedTabProvider, homeTabProvider, watchlistScrollTargetProvider, fabRaisedProvider)
    - _Requirements: 3.1, 3.4_

- [x] 4. Migrate flutter_dotenv test code
  - [x] 4.1 Update test/data/tmdb_service_test.dart
    - Change `dotenv.testLoad(fileInput: ...)` to `dotenv.loadFromString(fileInput: ...)`
    - _Requirements: 6.4_
  
  - [x] 4.2 Update test/data/tmdb_service_test_draft.dart
    - Change `dotenv.testLoad(fileInput: ...)` to `dotenv.loadFromString(fileInput: ...)`
    - _Requirements: 6.4_
  
  - [x] 4.3 Update test/data/services/tmdb_service_test.dart
    - Change `dotenv.testLoad(fileInput: ...)` to `dotenv.loadFromString(fileInput: ...)`
    - _Requirements: 6.4_

- [x] 5. Checkpoint - Verify compilation
  - Run `flutter analyze` to check for lint errors
  - Run `flutter pub get` to ensure dependencies resolve
  - Ensure all tests pass, ask the user if questions arise
  - _Requirements: 7.3, 8.1_

- [x] 6. Address lint warnings (if any)
  - [x] 6.1 Run flutter analyze and review new warnings
    - New lints: `strict_top_level_inference`, `unnecessary_underscores`
    - Fix warnings or add suppressions to analysis_options.yaml if needed
    - _Requirements: 7.1, 7.2_

- [x] 7. Verification and Testing
  - [x] 7.1 Run all unit tests
    - Execute `flutter test`
    - Verify all tests pass
    - _Requirements: 8.1_
  
  - [x] 7.2 Build for Windows
    - Execute `flutter build windows`
    - Verify build succeeds without errors
    - _Requirements: 8.2_
  
  - [x] 7.3 Build for Android
    - Execute `flutter build apk`
    - Verify build succeeds without errors
    - _Requirements: 8.3_

- [x] 8. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise
  - Verify the app launches and basic functionality works
  - _Requirements: 8.4, 8.5, 8.6_

## Notes

- All tasks are required for comprehensive verification
- The upgrade is minimal - only 4 files need code changes
- If SDK version is below 3.32, consider using flutter_local_notifications ^19.5.0 and flutter_lints ^5.0.0 instead
- Rollback: Restore pubspec.yaml.backup and pubspec.lock.backup, then run `flutter pub get`
