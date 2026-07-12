import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/database/entity/index.dart';

class UploadController extends GetxController {
  final entities = <UploadEntity>[].obs;
  final isFirstLoading = true.obs;
  final totalSize = 0.obs;
  final serverId = Get.find<UserStorage>().serverId.val.obs;

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() async {
    super.onInit();

    // Bind upload progress callback
    UploadService.to.bindCallback(_onUploadProgress);

    // Load all uploads
    await _loadUploads();
    isFirstLoading.value = false;
  }

  /// Load uploads from database
  Future<void> _loadUploads() async {
    entities.value =
        await DatabaseService.to.database.uploadDao.findAllUpload();
    resetTotalSize();
  }

  /// Upload progress callback
  void _onUploadProgress(int id, int progress, int status) {
    final index = entities.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final old = entities[index];
    entities[index] = UploadEntity(
      id: old.id,
      serverId: old.serverId,
      localPath: old.localPath,
      remotePath: old.remotePath,
      name: old.name,
      type: old.type,
      size: old.size,
      status: status,
      progress: progress,
      password: old.password,
      createdAt: old.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    entities.refresh();
  }

  /// Reset total size
  void resetTotalSize() {
    totalSize.value = entities.fold<int>(0, (sum, e) => sum + e.size);
  }

  /// Pause upload
  void pause(int id) async {
    await UploadService.to.pause(id);
    await _loadUploads();
  }

  /// Resume upload
  void resume(int id) async {
    await UploadService.to.resume(id);
    await _loadUploads();
  }

  /// Cancel upload
  void cancel(int id) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    await UploadService.to.cancel(id);
    await _loadUploads();
    SmartDialog.showToast('toast_remove_success'.tr);
  }

  /// Delete upload record
  void delete(int id) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    await UploadService.to.delete(id);
    await _loadUploads();
    SmartDialog.showToast('toast_remove_success'.tr);
  }

  /// Retry failed upload
  void retry(int id) async {
    await UploadService.to.retry(id);
    await _loadUploads();
  }

  /// Clear all completed/cancelled
  void clearFinished() async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message_all'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    for (final e in entities.toList()) {
      if (e.status == UploadStatus.COMPLETED ||
          e.status == UploadStatus.CANCELLED ||
          e.status == UploadStatus.FAILED) {
        await DatabaseService.to.database.uploadDao.deleteUploadById(e.id!);
      }
    }
    await _loadUploads();
    SmartDialog.showToast('toast_remove_success_all'.tr);
  }

  @override
  void onClose() {
    UploadService.to.unbindCallback(_onUploadProgress);
    super.onClose();
  }
}
