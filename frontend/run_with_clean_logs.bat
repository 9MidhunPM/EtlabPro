@echo off
echo Starting Flutter with filtered logs...
echo Press Ctrl+C to stop.
flutter run | findstr /V "D/FlutterJNI I/ImeTracker D/InsetsController D/InputConnectionAdaptor D/ProfileInstaller W/xample.etlabpro W/ZipArchive I/AssistStructure"
