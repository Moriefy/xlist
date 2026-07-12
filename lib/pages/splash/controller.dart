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

    // Wait a bit for native to process intent and set pendingSharedFile
    await Future.delayed(Duration(milliseconds: 500));

    // Check if native set shared file data via global handler
    final sharedData = Global.pendingSharedFile;
    if (sharedData != null) {
      Global.pendingSharedFile = null; // Clear
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

    // Also try polling native directly (in case handler wasn't ready)
    // This is a fallback for cold start
    try {
      const channel = MethodChannel('io.xlist/share');
      final result = await channel.invokeMethod('getSharedFile')
          .timeout(Duration(seconds: 2));
      if (result != null && result is Map && result.containsKey('filePath')) {
        final filePath = result['filePath'] as String? ?? '';
        final fileName = result['fileName'] as String? ?? '';
        final fileSize = result['fileSize'] as int? ?? 0;

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
    } catch (e) {
      // Method channel not ready, no shared file
    }

    // No shared file, go to homepage
    Get.offAllNamed(Routes.HOMEPAGE);
  }
}
