import 'package:permission_handler/permission_handler.dart';

// Request permissions
Future<void> requestPermissions() async {
  await Permission.camera.request();
  await Permission.storage.request();
}

// Check permissions
Future<bool> checkPermissions() async {
  return await Permission.camera.isGranted &&
      await Permission.storage.isGranted;
}
