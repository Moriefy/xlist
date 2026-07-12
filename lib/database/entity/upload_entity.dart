import 'package:floor/floor.dart';

@Entity(
  tableName: 'upload',
  indices: [
    Index(value: ['server_id', 'remote_path', 'name'], unique: true),
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
  final int status;

  @ColumnInfo(name: 'progress')
  final int progress;

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
    required this.status,
    required this.progress,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });
}
