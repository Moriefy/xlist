import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/upload_service.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/pages/setting/upload/index.dart';

class UploadPage extends GetView<UploadController> {
  const UploadPage({Key? key}) : super(key: key);

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: CommonUtils.backgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CommonUtils.backButton,
      middle: Text('upload_manager'.tr),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        child: Text('setting_upload_clear'.tr,
            style: TextStyle(color: CupertinoColors.systemRed)),
        onPressed: () => controller.clearFinished(),
      ),
    );
  }

  /// 构建图标
  Widget _buildIcon(int type, String name) {
    return Icon(
      FileType.getIcon(type, name),
      size: CommonUtils.isPad ? 60 : 130.sp,
      color: Get.theme.primaryColor,
    );
  }

  /// 状态文字
  String _statusText(int status, int progress) {
    switch (status) {
      case UploadStatus.QUEUED:
        return 'upload_queued'.tr;
      case UploadStatus.UPLOADING:
        return '$progress%';
      case UploadStatus.PAUSED:
        return '${'paused'.tr} $progress%';
      case UploadStatus.COMPLETED:
        return 'upload_completed'.tr;
      case UploadStatus.FAILED:
        return 'failed'.tr;
      case UploadStatus.CANCELLED:
        return 'upload_cancelled'.tr;
      default:
        return '';
    }
  }

  /// 状态颜色
  Color _statusColor(int status) {
    switch (status) {
      case UploadStatus.UPLOADING:
        return CupertinoColors.systemBlue;
      case UploadStatus.COMPLETED:
        return CupertinoColors.systemGreen;
      case UploadStatus.FAILED:
      case UploadStatus.CANCELLED:
        return CupertinoColors.systemRed;
      case UploadStatus.PAUSED:
        return CupertinoColors.systemOrange;
      case UploadStatus.QUEUED:
        return CupertinoColors.systemGrey;
      default:
        return Colors.grey;
    }
  }

  /// 构建进度条（所有状态都显示）
  Widget _buildProgressBar(int status, int progress) {
    final color = _statusColor(status);
    double value;
    switch (status) {
      case UploadStatus.UPLOADING:
        value = progress / 100.0;
        break;
      case UploadStatus.COMPLETED:
        value = 1.0;
        break;
      case UploadStatus.PAUSED:
        value = progress / 100.0;
        break;
      case UploadStatus.QUEUED:
        value = 0.0;
        break;
      default:
        value = 0.0;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.grey.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 8,
      ),
    );
  }

  /// 列表项
  Widget _buildItem(int index) {
    final entity = controller.entities[index];

    String path = entity.remotePath;
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    final statusStr = _statusText(entity.status, entity.progress);
    final statusClr = _statusColor(entity.status);

    return CupertinoListSection.insetGrouped(
      backgroundColor: CommonUtils.backgroundColor,
      margin: CommonUtils.isPad
          ? EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 5)
          : EdgeInsets.symmetric(horizontal: 50.w).copyWith(bottom: 30.h),
      children: [
        Container(
          height: CommonUtils.isPad ? 90 : 190.h,
          width: double.infinity,
          child: Slidable(
            // 右滑：暂停 / 恢复 / 取消
            startActionPane: _buildStartActions(entity),
            // 左滑：删除
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => controller.delete(entity.id!),
                  backgroundColor: Colors.red,
                  icon: CupertinoIcons.delete,
                  foregroundColor: Colors.white,
                  label: 'delete'.tr,
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 已完成的文件点击跳转到目录
              onTap: entity.status == UploadStatus.COMPLETED
                  ? () => controller.goToDirectory(entity)
                  : null,
              child: Row(
                children: [
                  SizedBox(width: 30.w),
                  _buildIcon(entity.type, entity.name),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entity.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Get.textTheme.bodyLarge?.copyWith(
                                  color: entity.status == UploadStatus.COMPLETED
                                      ? CupertinoColors.activeBlue
                                      : null,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              statusStr,
                              style: Get.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusClr,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          '${CommonUtils.formatFileSize(entity.size)} → ${path.isEmpty ? '/' : path}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodySmall?.copyWith(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // 所有状态都显示进度条
                        _buildProgressBar(entity.status, entity.progress),
                      ],
                    ),
                  ),
                  SizedBox(width: 20.w),
                  // 已完成的文件显示箭头
                  if (entity.status == UploadStatus.COMPLETED)
                    Padding(
                      padding: EdgeInsets.only(right: 20.w),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 40.sp,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 右滑操作面板（暂停/恢复/重试/取消）
  ActionPane? _buildStartActions(UploadEntity entity) {
    List<SlidableAction> actions = [];

    // 上传中 → 暂停
    if (entity.status == UploadStatus.UPLOADING) {
      actions.add(SlidableAction(
        onPressed: (context) => controller.pause(entity.id!),
        backgroundColor: Colors.grey,
        icon: CupertinoIcons.pause_circle,
        foregroundColor: Colors.white,
        label: 'paused'.tr,
      ));
    }

    // 暂停 → 恢复
    if (entity.status == UploadStatus.PAUSED) {
      actions.add(SlidableAction(
        onPressed: (context) => controller.resume(entity.id!),
        backgroundColor: Get.theme.primaryColor,
        icon: CupertinoIcons.play_circle,
        foregroundColor: Colors.white,
        label: 'resume'.tr,
      ));
    }

    // 失败/取消 → 重试
    if (entity.status == UploadStatus.FAILED ||
        entity.status == UploadStatus.CANCELLED) {
      actions.add(SlidableAction(
        onPressed: (context) => controller.retry(entity.id!),
        backgroundColor: Get.theme.primaryColor,
        icon: CupertinoIcons.refresh_circled,
        foregroundColor: Colors.white,
        label: 'upload_retry'.tr,
      ));
    }

    // 队列中/上传中 → 取消
    if (entity.status == UploadStatus.QUEUED ||
        entity.status == UploadStatus.UPLOADING) {
      actions.add(SlidableAction(
        onPressed: (context) => controller.cancel(entity.id!),
        backgroundColor: CupertinoColors.systemRed,
        icon: CupertinoIcons.xmark_circle,
        foregroundColor: Colors.white,
        label: 'cancel'.tr,
      ));
    }

    if (actions.isEmpty) return null;
    return ActionPane(motion: ScrollMotion(), children: actions);
  }

  /// SliverList
  Widget _buildSliverList() {
    if (controller.isFirstLoading.isTrue) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 500.h),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (controller.entities.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: 500.h),
            Assets.images.empty.image(width: 600.r),
            SizedBox(height: 30.h),
            Text('setting_upload_empty'.tr, style: Get.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => FrameSeparateWidget(
          index: index,
          child: Obx(() => _buildItem(index)),
        ),
        childCount: controller.entities.length,
      ),
    );
  }

  // ScrollView
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      shrinkWrap: false,
      controller: controller.scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: controller.entities.isNotEmpty
              ? Container(
                  padding: CommonUtils.isPad
                      ? EdgeInsets.only(left: 40, top: 30.h, bottom: 10.h)
                      : EdgeInsets.only(left: 80.w, top: 30.h, bottom: 10.h),
                  child: Obx(
                    () => Text(
                        '${'setting_upload_total'.tr} ${controller.entities.length}${'setting_upload_manager_file'.tr}',
                        style: Get.textTheme.bodySmall),
                  ),
                )
              : SizedBox(),
        ),
        Obx(() => SizeCacheWidget(child: _buildSliverList())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: CommonUtils.backgroundColor,
      child: Obx(
        () => controller.isFirstLoading.isTrue
            ? Center(child: CupertinoActivityIndicator())
            : _buildCustomScrollView(),
      ),
    );
  }
}
