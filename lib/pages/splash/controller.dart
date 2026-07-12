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

    // Jump to LandingPage after 10ms
    Timer(const Duration(milliseconds: 10), () => complete());
  }

  void complete() async {
    if (!CommonUtils.isPad) await FijkPlugin.setOrientationPortrait();

    // 布局方式
    final layoutType = Get.find<PreferencesStorage>().layoutType.val;
    if (layoutType == LayoutType.UNKNOWN) {
      Get.find<PreferencesStorage>().layoutType.val =
          CommonUtils.isPad ? LayoutType.GRID : LayoutType.LIST;
    }

    // 检查是否有分享 Intent
    try {
      final result = await _channel.invokeMethod('getSharedFile');
      if (result != null && result is Map) {
        final filePath = result['filePath'] as String? ?? '';
        final fileName = result['fileName'] as String? ?? '';
        final fileSize = result['fileSize'] as int? ?? 0;

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
    } catch (e) {
      // No share intent, continue normally
    }

    // 跳转到首页
    Get.offAndToNamed(Routes.HOMEPAGE);
  }
}
