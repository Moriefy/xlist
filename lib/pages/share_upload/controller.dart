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
  final userInfo = UserModel().obs;
  final objects = <ObjectModel>[].obs;
  final isFirstLoading = true.obs;
  final serverId = Get.find<UserStorage>().serverId.val;
  final isShowPreview = Get.find<PreferencesStorage>().isShowPreview.val.obs;

  // Shared file info from arguments
  String filePath = Get.arguments?['filePath'] ?? '';
  String fileName = Get.arguments?['fileName'] ?? '';
  int fileSize = Get.arguments?['fileSize'] ?? 0;
  String mimeType = Get.arguments?['mimeType'] ?? '';

  // Current directory path
  String path = Get.arguments?['path'] ?? '/';

  // ScrollController
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

    // Get directory password
    final passwordManager = await DatabaseService.to.database.passwordManagerDao
        .findPasswordManagerByPath(serverId, path);
    if (passwordManager != null && passwordManager.isNotEmpty) {
      password = passwordManager.last.password;
    }

    // Get user info
    try {
      userInfo.value = await UserRepository.me();
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
        .map(
          (d) => ObjectModel.fromJson(
            {
              'name': d.name,
              'is_dir': true,
              'type': FileType.FOLDER,
              'size': 0,
              'modified': d.modified?.toIso8601String(),
            },
          ),
        )
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
        'mimeType': mimeType,
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

    // Determine file type
    int fileType = FileType.UNKNOWN;
    if (PreviewHelper.isImage(fileName)) {
      fileType = FileType.IMAGE;
    } else if (PreviewHelper.isVideo(fileName)) {
      fileType = FileType.VIDEO;
    } else if (PreviewHelper.isAudio(fileName)) {
      fileType = FileType.AUDIO;
    }

    // Add to upload queue
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

    // Go back to home
    Get.until((route) => route.isFirst);
  }

  /// Cancel and go back
  void cancel() {
    Get.back();
  }
}
