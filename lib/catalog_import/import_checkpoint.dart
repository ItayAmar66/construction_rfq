import 'dart:convert';
import 'dart:io';

/// Persists import progress for resume (deterministic doc IDs + batch offset).
class ImportCheckpoint {
  ImportCheckpoint({
    required this.importVersion,
    required this.phase,
    required this.skipped,
    required this.total,
    required this.updatedAt,
  });

  final String importVersion;
  final String phase;
  final int skipped;
  final int total;
  final DateTime updatedAt;

  static const phases = ['categories', 'products', 'variants', 'meta'];

  factory ImportCheckpoint.fromJson(Map<String, dynamic> json) {
    return ImportCheckpoint(
      importVersion: json['importVersion'] as String? ?? '',
      phase: json['phase'] as String? ?? 'categories',
      skipped: json['skipped'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'importVersion': importVersion,
        'phase': phase,
        'skipped': skipped,
        'total': total,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static Future<ImportCheckpoint?> load(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ImportCheckpoint.fromJson(json);
  }

  static Future<void> save(String path, ImportCheckpoint checkpoint) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(checkpoint.toJson()),
    );
  }

  static Future<void> clear(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  static String defaultPathForOutputDir(String outputDir) =>
      '$outputDir/import_checkpoint.json';
}
