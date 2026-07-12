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

    // Warm start listener: Native pushes share data to Dart
    _setupShareIntentListener();
  }

  static void _setupShareIntentListener() {
    const channel = MethodChannel('io.xlist/share');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        final data = call.arguments as Map?;
        if (data == null) return;

        final filePath = data['filePath'] as String? ?? '';
        final fileName = data['fileName'] as String? ?? '';
        final fileSize = data['fileSize'] as int? ?? 0;

        if (filePath.isNotEmpty && File(filePath).existsSync()) {
          // App is already running, navigate directly
          Get.offAllNamed(Routes.SHARE_UPLOAD, arguments: {
            'filePath': filePath,
            'fileName': fileName,
            'fileSize': fileSize,
            'path': '/',
          });
        }
      }
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
