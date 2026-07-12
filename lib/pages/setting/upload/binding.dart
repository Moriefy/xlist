import 'package:get/get.dart';

import 'package:xlist/pages/setting/upload/index.dart';

class UploadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UploadController>(() => UploadController());
  }
}
