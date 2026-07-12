import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/services.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';

class SplashController extends GetxController {
  static const _channel = MethodChannel('io.xlist/share');

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    if (!CommonUtils.isPad) await FijkPlugin.setOrientationPortrait();

    final layoutType = Get.find<PreferencesStorage>().layoutType.val;
    if (layoutType == LayoutType.UNKNOWN) {
      Get.find<PreferencesStorage>().layoutType.val =
          CommonUtils.isPad ? LayoutType.GRID : LayoutType.LIST;
    }

    // Cold start: poll native for shared file
    // Native caches it before Flutter engine starts, but the method channel
    // handler might not be fully ready, so retry multiple times.
    Map? sharedData;
    for (int i = 0; i < 15; i++) {
      try {
        final result = await _channel.invokeMethod('getSharedFile')
            .timeout(Duration(seconds: 1));
        if (result != null && result is Map && result.containsKey('filePath')) {
          sharedData = result;
          break;
        }
        // null = no shared file cached, no point retrying
        break;
      } catch (e) {
        // Timeout or MissingPluginException, retry
        await Future.delayed(Duration(milliseconds: 200));
      }
    }

    if (sharedData != null) {
      final filePath = sharedData['filePath'] as String? ?? '';
      final fileName = sharedData['fileName'] as String? ?? '';
      final fileSize = sharedData['fileSize'] as int? ?? 0;

      if (filePath.isNotEmpty && File(filePath).existsSync()) {
        Get.offAllNamed(Routes.SHARE_UPLOAD, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileSize': fileSize,
          'path': '/',
        });
        return;
      }
    }

    // No shared file, go to homepage
    Get.offAllNamed(Routes.HOMEPAGE);
  }
}
