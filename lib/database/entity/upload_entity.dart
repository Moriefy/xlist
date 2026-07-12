import 'package:floor/floor.dart';

@Entity(
  tableName: 'upload',
  indices: [
    Index(value: ['server_id', 'path', 'name'], unique: true),
  ],
)
class UploadEntity {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  @ColumnInfo(name: 'server_id')
  final int serverId;

  @ColumnInfo(name: 'local_path')
  final String localPath;

  @ColumnInfo(name: 'remote_path')
  final String remotePath;

  @ColumnInfo(name: 'name')
  final String name;

  @ColumnInfo(name: 'type')
  final int type;

  @ColumnInfo(name: 'size')
  final int size;

  @ColumnInfo(name: 'status')
  final int status; // 0=queued, 1=uploading, 2=paused, 3=completed, 4=failed, 5=cancelled

  @ColumnInfo(name: 'progress')
  final int progress; // 0-100

  @ColumnInfo(name: 'password')
  final String password;

  @ColumnInfo(name: 'created_at')
  final int createdAt;

  @ColumnInfo(name: 'updated_at')
  final int updatedAt;

  UploadEntity({
    this.id,
    required this.serverId,
    required this.localPath,
    required this.remotePath,
    required this.name,
    required this.type,
    required this.size,
    this.status = 0,
    this.progress = 0,
    this.password = '',
    required this.createdAt,
    required this.updatedAt,
  });
}
