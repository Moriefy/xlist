import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';

class SplashController extends GetxController {
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
      final sharedFiles = await ReceiveSharingIntent.getInitialMedia();
      if (sharedFiles.isNotEmpty) {
        final file = sharedFiles.first;
        final filePath = file.path;
        final fileName = filePath.split(Platform.pathSeparator).last;
        final fileSize = File(filePath).lengthSync();

        Get.offAndToNamed(Routes.SHARE_UPLOAD, arguments: {
          'filePath': filePath,
          'fileName': fileName,
          'fileSize': fileSize,
          'mimeType': '',
          'path': '/',
        });
        return;
      }
    } catch (e) {
      // No share intent, continue normally
    }

    // 跳转到首页
    Get.offAndToNamed(Routes.HOMEPAGE);
  }
}
