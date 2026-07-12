import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/pages/share_upload/index.dart';
import 'package:xlist/components/object_list/object_list_item.dart';

class ShareUploadPage extends GetView<ShareUploadController> {
  const ShareUploadPage({Key? key}) : super(key: key);

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        child: Icon(FontAwesomeIcons.xmark, size: CommonUtils.navIconSize),
        onPressed: () => controller.cancel(),
      ),
      middle: Text(
        controller.pageTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        child: Icon(
          CupertinoIcons.folder_badge_plus,
          size: CommonUtils.navIconSize,
        ),
        onPressed: () => _showNewFolderDialog(),
      ),
    );
  }

  /// New folder dialog
  void _showNewFolderDialog() async {
    final data = await showTextInputDialog(
      context: Get.context!,
      title: 'dialog_mkdir_title'.tr,
      message: 'dialog_mkdir_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
      textFields: [DialogTextField(hintText: 'dialog_mkdir_hint'.tr)],
    );
    if (data == null || data.isEmpty) return;

    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.mkdir(
          path: '${controller.path}/${data.first}');
      if (response['code'] != 200) throw response['message'];
      SmartDialog.dismiss();
      SmartDialog.showToast('toast_mkdir_success'.tr);
      await controller.getDirectoryList();
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// Current path display
  Widget _buildPathIndicator() {
    return Container(
      padding: CommonUtils.isPad
          ? EdgeInsets.symmetric(horizontal: 20, vertical: 10)
          : EdgeInsets.symmetric(horizontal: 50.w, vertical: 15.h),
      child: Row(
        children: [
          Icon(CupertinoIcons.folder_fill,
              size: 40.sp, color: CupertinoColors.systemBlue),
          SizedBox(width: 15.w),
          Expanded(
            child: Text(
              controller.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Get.textTheme.bodySmall?.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SliverList — GestureDetector is INSIDE Slidable (same as DirectoryPage)
  Widget _buildSliverList() {
    if (controller.isFirstLoading.isTrue) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 500.h),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (controller.objects.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: 300.h),
            Assets.images.empty.image(width: 400.r),
            SizedBox(height: 20.h),
            Text(
              'directory_empty_description'.tr,
              style: Get.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => FrameSeparateWidget(
          index: index,
          child: Slidable(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  controller.enterDirectory(controller.objects[index]),
              child: Column(
                children: [
                  ObjectListItem(
                    object: controller.objects[index],
                    isShowPreview: false,
                  ),
                  CommonUtils.isPad
                      ? Divider(height: 1.r, indent: 90, endIndent: 10)
                      : Container(
                          padding: EdgeInsets.only(top: 20.r),
                          child: Divider(
                              height: 1.r, indent: 190.r, endIndent: 15.r),
                        ),
                ],
              ),
            ),
          ),
        ),
        childCount: controller.objects.length,
      ),
    );
  }

  // ScrollView
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      shrinkWrap: false,
      controller: controller.scrollController,
      slivers: <Widget>[
        HeaderLocator.sliver(),
        SliverToBoxAdapter(child: _buildPathIndicator()),
        Obx(
          () => SliverPadding(
            padding: EdgeInsets.symmetric(
                horizontal: CommonUtils.isPad ? 15 : 30.r),
            sliver: SizeCacheWidget(child: _buildSliverList()),
          ),
        ),
        FooterLocator.sliver(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildNavigationBar(),
      body: SafeArea(
        child: EasyRefresh(
          controller: controller.easyRefreshController,
          header: CupertinoHeader(
              position: IndicatorPosition.locator, safeArea: false),
          footer: CupertinoFooter(position: IndicatorPosition.locator),
          onRefresh: () async {
            await HapticFeedback.selectionClick();
            await controller.getDirectoryList();
            controller.easyRefreshController.finishRefresh();
            controller.easyRefreshController.resetFooter();
          },
          child: _buildCustomScrollView(),
        ),
      ),
      // Bottom bar: file info + Upload/Cancel buttons
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(40.r, 20.r, 40.r, 30.r),
          decoration: BoxDecoration(
            color: Get.theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(width: 1.r, color: Get.theme.dividerColor),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // File info row
              Row(
                children: [
                  Icon(
                    FileType.getIcon(0, controller.fileName),
                    size: CommonUtils.isPad ? 50 : 90.sp,
                    color: Get.theme.primaryColor,
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${CommonUtils.formatFileSize(controller.fileSize)} → ${controller.path}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodySmall?.copyWith(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 25.h),
              // Buttons row
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      color: isDark
                          ? CupertinoColors.systemGrey4
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(25.r),
                      child: Text(
                        'cancel'.tr,
                        style: Get.textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => controller.cancel(),
                    ),
                  ),
                  SizedBox(width: 30.w),
                  // Upload button
                  Expanded(
                    flex: 2,
                    child: CupertinoButton.filled(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      borderRadius: BorderRadius.circular(25.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.cloud_upload,
                              color: Colors.white, size: 45.sp),
                          SizedBox(width: 10.w),
                          Text(
                            'share_upload_button'.tr,
                            style: Get.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => controller.uploadHere(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
