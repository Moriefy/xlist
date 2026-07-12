import 'package:get/get.dart';

import 'package:xlist/pages/share_upload/index.dart';

class ShareUploadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShareUploadController>(() => ShareUploadController());
  }
}
