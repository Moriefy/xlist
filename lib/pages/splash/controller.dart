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
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    if (!CommonUtils.isPad) await FijkPlugin.setOrientationPortrait();

    // 布局方式
    final layoutType = Get.find<PreferencesStorage>().layoutType.val;
    if (layoutType == LayoutType.UNKNOWN) {
      Get.find<PreferencesStorage>().layoutType.val =
          CommonUtils.isPad ? LayoutType.GRID : LayoutType.LIST;
    }

    // Wait for engine to be ready with retry
    Map? sharedData;
    for (int i = 0; i < 5; i++) {
      try {
        final result = await _channel.invokeMethod('getSharedFile')
            .timeout(Duration(seconds: 2));
        if (result != null && result is Map) {
          sharedData = result;
          break;
        }
        // null means no shared file, stop retrying
        break;
      } catch (e) {
        // Timeout or error, retry after delay
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    // Check if we got shared file data
    if (sharedData != null) {
      final filePath = sharedData['filePath'] as String? ?? '';
      final fileName = sharedData['fileName'] as String? ?? '';
      final fileSize = sharedData['fileSize'] as int? ?? 0;

      if (filePath.isNotEmpty && File(filePath).existsSync()) {
        Get.offAndToNamed(Routes.SHARE_UPLOAD, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileSize': fileSize,
          'mimeType': '',
          'path': '/',
        });
        return;
      }
    }

    // No shared file, go to homepage
    Get.offAndToNamed(Routes.HOMEPAGE);
  }
}
