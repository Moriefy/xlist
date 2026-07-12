import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/database/entity/index.dart';

// Upload status constants
class UploadStatus {
  static const int QUEUED = 0;
  static const int UPLOADING = 1;
  static const int PAUSED = 2;
  static const int COMPLETED = 3;
  static const int FAILED = 4;
  static const int CANCELLED = 5;
}

typedef UploadProgressCallback = void Function(int id, int progress, int status);

class UploadService extends GetxService {
  static UploadService get to => Get.find();

  final _cancelTokens = <int, CancelToken>{};
  final _callbacks = <UploadProgressCallback>[];
  bool _processing = false;

  Future<UploadService> init() async {
    // Resume any queued uploads on startup
    _processQueue();
    return this;
  }

  /// Register a progress callback
  void bindCallback(UploadProgressCallback callback) {
    _callbacks.add(callback);
  }

  /// Unregister a progress callback
  void unbindCallback(UploadProgressCallback callback) {
    _callbacks.remove(callback);
  }

  /// Notify all listeners
  void _notify(int id, int progress, int status) {
    for (final cb in _callbacks) {
      cb(id, progress, status);
    }
  }

  /// Enqueue a file for upload
  Future<int> enqueue({
    required int serverId,
    required String localPath,
    required String remotePath,
    required String name,
    required int type,
    required int size,
    String password = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entity = UploadEntity(
      serverId: serverId,
      localPath: localPath,
      remotePath: remotePath,
      name: name,
      type: type,
      size: size,
      password: password,
      createdAt: now,
      updatedAt: now,
    );

    final id = await DatabaseService.to.database.uploadDao.insertUpload(entity);
    _processQueue();
    return id;
  }

  /// Process the upload queue (one at a time)
  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;

    while (true) {
      // Find next queued upload
      final actives = await DatabaseService.to.database.uploadDao.findActiveUploads();
      final queued = actives.where((e) => e.status == UploadStatus.QUEUED).toList();
      if (queued.isEmpty) break;

      final entity = queued.first;
      await _doUpload(entity);
    }

    _processing = false;
  }

  /// Execute a single upload
  Future<void> _doUpload(UploadEntity entity) async {
    final cancelToken = CancelToken();
    _cancelTokens[entity.id!] = cancelToken;

    // Update status to uploading
    await _updateEntity(entity, status: UploadStatus.UPLOADING, progress: 0);
    _notify(entity.id!, 0, UploadStatus.UPLOADING);

    try {
      final file = File(entity.localPath);
      if (!await file.exists()) {
        await _updateEntity(entity, status: UploadStatus.FAILED);
        _notify(entity.id!, entity.progress, UploadStatus.FAILED);
        _cancelTokens.remove(entity.id);
        return;
      }

      final fileData = await file.readAsBytes();
      final url = Get.find<UserStorage>().serverUrl.val;
      final token = Get.find<UserStorage>().token.val;

      await DioService.to.dio.put(
        '${url}/api/fs/put',
        cancelToken: cancelToken,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'File-Path': Uri.encodeComponent('${entity.remotePath}/${entity.name}'),
            'Password': entity.password,
            'Content-Length': fileData.length,
            'Authorization': token,
          },
        ),
        data: MultipartFile.fromBytes(fileData).finalize(),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = (sent * 100 ~/ total);
            _updateEntityProgress(entity.id!, progress);
            _notify(entity.id!, progress, UploadStatus.UPLOADING);
          }
        },
      );

      // Completed
      await _updateEntity(entity, status: UploadStatus.COMPLETED, progress: 100);
      _notify(entity.id!, 100, UploadStatus.COMPLETED);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Cancelled - check if paused or cancelled
        final current = await DatabaseService.to.database.uploadDao.findUploadById(entity.id!);
        if (current != null && current.status == UploadStatus.PAUSED) {
          // Keep paused state
          _notify(entity.id!, current.progress, UploadStatus.PAUSED);
        } else {
          await _updateEntity(entity, status: UploadStatus.CANCELLED);
          _notify(entity.id!, entity.progress, UploadStatus.CANCELLED);
        }
      } else {
        await _updateEntity(entity, status: UploadStatus.FAILED);
        _notify(entity.id!, entity.progress, UploadStatus.FAILED);
      }
    } catch (e) {
      await _updateEntity(entity, status: UploadStatus.FAILED);
      _notify(entity.id!, entity.progress, UploadStatus.FAILED);
    }

    _cancelTokens.remove(entity.id);
  }

  /// Pause an upload
  Future<void> pause(int id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('paused');
    }
    await _updateEntityById(id, status: UploadStatus.PAUSED);
    _notify(id, 0, UploadStatus.PAUSED);
  }

  /// Resume a paused upload
  Future<void> resume(int id) async {
    await _updateEntityById(id, status: UploadStatus.QUEUED);
    _notify(id, 0, UploadStatus.QUEUED);
    _processQueue();
  }

  /// Cancel an upload
  Future<void> cancel(int id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('cancelled');
    }
    await _updateEntityById(id, status: UploadStatus.CANCELLED);
    _notify(id, 0, UploadStatus.CANCELLED);
  }

  /// Delete an upload record
  Future<void> delete(int id) async {
    await cancel(id);
    await DatabaseService.to.database.uploadDao.deleteUploadById(id);
  }

  /// Retry a failed upload
  Future<void> retry(int id) async {
    await _updateEntityById(id, status: UploadStatus.QUEUED, progress: 0);
    _notify(id, 0, UploadStatus.QUEUED);
    _processQueue();
  }

  /// Update entity by id
  Future<void> _updateEntityById({
    required int id,
    int? status,
    int? progress,
  }) async {
    final entity = await DatabaseService.to.database.uploadDao.findUploadById(id);
    if (entity == null) return;
    await _updateEntity(entity, status: status, progress: progress);
  }

  /// Update entity
  Future<void> _updateEntity(
    UploadEntity entity, {
    int? status,
    int? progress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseService.to.database.uploadDao.updateUpload(UploadEntity(
      id: entity.id,
      serverId: entity.serverId,
      localPath: entity.localPath,
      remotePath: entity.remotePath,
      name: entity.name,
      type: entity.type,
      size: entity.size,
      status: status ?? entity.status,
      progress: progress ?? entity.progress,
      password: entity.password,
      createdAt: entity.createdAt,
      updatedAt: now,
    ));
  }

  /// Update progress only (lightweight)
  Future<void> _updateEntityProgress(int id, int progress) async {
    final entity = await DatabaseService.to.database.uploadDao.findUploadById(id);
    if (entity == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseService.to.database.uploadDao.updateUpload(UploadEntity(
      id: entity.id,
      serverId: entity.serverId,
      localPath: entity.localPath,
      remotePath: entity.remotePath,
      name: entity.name,
      type: entity.type,
      size: entity.size,
      status: entity.status,
      progress: progress,
      password: entity.password,
      createdAt: entity.createdAt,
      updatedAt: now,
    ));
  }
}
