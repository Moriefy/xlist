import 'dart:io';
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';

class Global {
  static bool get isRelease => kReleaseMode;
  static bool get isProfile => kProfileMode;
  static bool get isDebug => kDebugMode;

  /// Shared file data from intent (set by method channel handler)
  /// Splash controller reads this instead of polling the method channel.
  static Map<String, dynamic>? pendingSharedFile;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = XlistHttpOverrides();
    await GetStorage.init();

    await Get.put(CommonStorage());
    await Get.putAsync(() => UserStorage().init());
    await Get.putAsync(() => PreferencesStorage().init());

    await Get.put(BrowserService());
    await Get.putAsync(() => DioService().init());
    await Get.putAsync(() => DatabaseService().init());
    await Get.putAsync(() => DownloadService().init());
    await Get.putAsync(() => DeviceInfoService().init());
    await Get.putAsync(() => PlayerNotificationService().init());
    await Get.putAsync(() => UploadService().init());

    final isFirstOpen = Get.find<PreferencesStorage>().isFirstOpen;
    if (isFirstOpen.val == true) {
      isFirstOpen.val = false;
      try {
        if (GetPlatform.isIOS) DioService.to.dio.get('https://xlist.site');
      } catch (e) {}
    }

    Get.changeThemeMode(ThemeModeMap[Get.find<CommonStorage>().themeMode.val]!);

    if (GetPlatform.isAndroid) {
      SystemUiOverlayStyle systemUiOverlayStyle =
          const SystemUiOverlayStyle(statusBarColor: Colors.transparent);
      SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    }

    // Set up method channel handler ONCE (handles both cold and warm start)
    _setupShareIntentHandler();
  }

  /// Single method channel handler for share intents.
  /// Handles:
  /// - getSharedFile: Dart polls native (cold start)
  /// - onSharedFile: Native pushes to Dart (warm start)
  static void _setupShareIntentHandler() {
    const channel = MethodChannel('io.xlist/share');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        // Warm start: native pushes shared file data
        final data = call.arguments as Map?;
        if (data != null) {
          final filePath = data['filePath'] as String? ?? '';
          final fileName = data['fileName'] as String? ?? '';
          final fileSize = data['fileSize'] as int? ?? 0;

          if (filePath.isNotEmpty && File(filePath).existsSync()) {
            // Store for splash controller to read
            pendingSharedFile = {
              'filePath': filePath,
              'fileName': fileName,
              'fileSize': fileSize,
            };

            // If app is already on homepage, navigate directly
            if (Get.currentRoute == Routes.HOMEPAGE ||
                Get.currentRoute == '/') {
              Get.offAllNamed(Routes.SHARE_UPLOAD, arguments: {
                'filePath': filePath,
                'fileName': fileName,
                'fileSize': fileSize,
                'path': '/',
              });
            }
          }
        }
      }
      // getSharedFile is handled by native side, not here
    });
  }
}

class XlistHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final SecurityContext sc = SecurityContext();
    sc.allowLegacyUnsafeRenegotiation = true;
    return super.createHttpClient(sc)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
