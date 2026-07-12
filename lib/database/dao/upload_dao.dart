import 'package:floor/floor.dart';

import 'package:xlist/database/entity/index.dart';

@dao
abstract class UploadDao {
  @Query('SELECT * FROM upload ORDER BY created_at DESC')
  Future<List<UploadEntity>> findAllUpload();

  @Query('SELECT * FROM upload WHERE id = :id')
  Future<UploadEntity?> findUploadById(int id);

  @Query(
    'SELECT * FROM upload WHERE server_id = :serverId AND remote_path = :path AND name = :name',
  )
  Future<UploadEntity?> findUploadByServerIdAndPath(
      int serverId, String path, String name);

  @Query('SELECT * FROM upload WHERE status = 0 OR status = 1')
  Future<List<UploadEntity>> findActiveUploads();

  @Query('DELETE FROM upload WHERE id = :id')
  Future<void> deleteUploadById(int id);

  @Query('DELETE FROM upload WHERE server_id = :serverId')
  Future<void> deleteUploadByServerId(int serverId);

  @insert
  Future<int> insertUpload(UploadEntity upload);

  @update
  Future<int> updateUpload(UploadEntity upload);
}
