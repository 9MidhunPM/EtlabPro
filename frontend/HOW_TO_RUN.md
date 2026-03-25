# EtlabPro Frontend Run and Build Guide

This project is a Flutter app.

## 1) One place to edit runtime variables

Edit only this file for backend URL and runtime settings:

- .env

Current required variable:

- API_BASE_URL=

If .env is missing, the app falls back to build-time define and then a hosted default.

## 2) Run locally (debug)

From the frontend folder:

1. flutter pub get
2. flutter run

That is all. No --dart-define flag is required.

## 3) Build APK (debug)

1. flutter build apk --debug
2. Output: build/app/outputs/flutter-apk/app-debug.apk

## 4) Build official release APK (signed)

### Step A: Create upload keystore

From frontend/android/app:

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

### Step B: Create android/key.properties

Create file: android/key.properties

Add:

storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks

Important: keep this file private. Do not commit it.

### Step C: Wire signing config in android/app/build.gradle.kts

Add a release signingConfig that reads android/key.properties and use it in buildTypes.release.

### Step D: Build release APK

1. flutter build apk --release
2. Output: build/app/outputs/flutter-apk/app-release.apk

This is your official signed release APK.

## 5) Optional split-per-ABI release (smaller APKs)

flutter build apk --release --split-per-abi

Outputs are under:

- build/app/outputs/flutter-apk/

## 6) Safety notes

- .env is gitignored in frontend/.gitignore
- Do not commit key.properties or keystore files
- Keep secrets only in local env and local signing files
