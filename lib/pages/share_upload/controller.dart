import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/database/entity/index.dart';

class ShareUploadController extends GetxController {
  final objects = <ObjectModel>[].obs;
  final isFirstLoading = true.obs;
  final serverId = Get.find<UserStorage>().serverId.val;
  final isShowPreview = false.obs;

  // Shared file info
  String filePath = Get.arguments?['filePath'] ?? '';
  String fileName = Get.arguments?['fileName'] ?? '';
  int fileSize = Get.arguments?['fileSize'] ?? 0;

  // Current directory path
  String path = Get.arguments?['path'] ?? '/';

  final ScrollController scrollController = ScrollController();
  EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  String password = '';
  late String pageTitle;

  @override
  void onInit() async {
    super.onInit();
    pageTitle = 'share_upload_title'.tr;

    try {
      final passwordManager = await DatabaseService.to.database.passwordManagerDao
          .findPasswordManagerByPath(serverId, path);
      if (passwordManager != null && passwordManager.isNotEmpty) {
        password = passwordManager.last.password;
      }
    } catch (e) {}

    await getDirectoryList();
    isFirstLoading.value = false;
  }

  /// Get directory list
  Future<void> getDirectoryList() async {
    try {
      final response =
          await ObjectRepository.getDirs(path: path, password: password);

      if (response['code'] == 403) {
        final text = await showTextInputDialog(
          context: Get.context!,
          title: 'detail_dialog_password_title'.tr,
          message: 'detail_dialog_password_message'.tr,
          okLabel: 'confirm'.tr,
          cancelLabel: 'cancel'.tr,
          textFields: [
            DialogTextField(hintText: 'detail_dialog_password_hint'.tr),
          ],
        );
        if (text == null) {
          Get.back();
          return;
        }
        await DatabaseService.to.database.passwordManagerDao
            .insertPasswordManager(PasswordManagerEntity(
                serverId: serverId, path: path, password: text.first));
        password = text.first;
        await getDirectoryList();
        return;
      }

      objects.clear();
      objects.addAll(formatData(response));
      objects.refresh();
    } catch (e) {
      print(e);
    }
  }

  /// Format data
  List<ObjectModel> formatData(dynamic response) {
    final List<FsDirsModel> dirs = [];
    final data = response['data'] ?? [];
    data.map((d) => dirs.add(FsDirsModel.fromJson(d))).toList();
    return dirs
        .map((d) => ObjectModel.fromJson({
              'name': d.name,
              'is_dir': true,
              'type': FileType.FOLDER,
              'size': 0,
              'modified': d.modified?.toIso8601String(),
            }))
        .toList();
  }

  /// Navigate into a subdirectory
  void enterDirectory(ObjectModel object) {
    final newPath = '${path == '/' ? '' : path}/${object.name}';
    Get.toNamed(
      Routes.SHARE_UPLOAD,
      arguments: {
        'path': newPath,
        'object': object,
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
      },
    );
  }

  /// Upload the shared file to current directory
  Future<void> uploadHere() async {
    if (filePath.isEmpty) {
      SmartDialog.showToast('share_upload_no_file'.tr);
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      SmartDialog.showToast('share_upload_file_not_found'.tr);
      return;
    }

    int fileType = FileType.UNKNOWN;
    if (PreviewHelper.isImage(fileName)) {
      fileType = FileType.IMAGE;
    } else if (PreviewHelper.isVideo(fileName)) {
      fileType = FileType.VIDEO;
    } else if (PreviewHelper.isAudio(fileName)) {
      fileType = FileType.AUDIO;
    }

    await UploadService.to.enqueue(
      serverId: serverId,
      localPath: filePath,
      remotePath: path,
      name: fileName,
      type: fileType,
      size: fileSize,
      password: password,
    );

    SmartDialog.showToast('toast_upload_added'.tr);
    // Go to homepage
    Get.offAllNamed(Routes.HOMEPAGE);
  }

  /// Cancel — go to homepage (or close if it's the only route)
  void cancel() {
    if (Get.routing.current == Routes.SHARE_UPLOAD) {
      // We're on share upload, go to homepage
      Get.offAllNamed(Routes.HOMEPAGE);
    } else {
      Get.back();
    }
  }
}
