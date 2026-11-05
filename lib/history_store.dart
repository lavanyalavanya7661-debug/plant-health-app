import 'dart:convert';
import 'dart:io';
 
import 'package:path_provider/path_provider.dart';
 
import 'classifier.dart';
 
/// Keep only the newest scans so the phone's storage does not fill up.
const int kMaxHistory = 100;
 
/// One saved scan: photo path, top predictions, time.
class HistoryEntry {
  final String id; // also the photo file name
  final String imagePath;
  final DateTime time;
  final List<Prediction> predictions; // best first
 
  const HistoryEntry({
    required this.id,
    required this.imagePath,
    required this.time,
    required this.predictions,
  });
 
  Prediction get top => predictions.first;
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'time': time.toIso8601String(),
        'predictions': [
          for (final p in predictions) {'label': p.rawLabel, 'conf': p.confidence}
        ],
      };
 
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        imagePath: j['imagePath'] as String,
        time: DateTime.parse(j['time'] as String),
        predictions: [
          for (final p in (j['predictions'] as List))
            Prediction(p['label'] as String, (p['conf'] as num).toDouble())
        ],
      );
}
 
/// Saves scan history on the phone: photos in a folder, details in one JSON file.
class HistoryStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scan_history');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
 
  Future<File> _indexFile() async => File('${(await _dir()).path}/index.json');
 
  /// Newest first.
  Future<List<HistoryEntry>> load() async {
    try {
      final f = await _indexFile();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // a damaged file should never crash the app
    }
  }
 
  Future<void> _write(List<HistoryEntry> items) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }
 
  /// Copies the photo into the app folder and records the result.
  Future<void> add(File photo, List<Prediction> predictions) async {
    final dir = await _dir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final saved = await photo.copy('${dir.path}/$id.jpg');
 
    final items = await load();
    items.insert(
      0,
      HistoryEntry(
        id: id,
        imagePath: saved.path,
        time: DateTime.now(),
        predictions: predictions,
      ),
    );
 
    // Drop the oldest scans (and their photos) beyond the limit.
    while (items.length > kMaxHistory) {
      final old = items.removeLast();
      await _deleteFile(old.imagePath);
    }
    await _write(items);
  }
 
  Future<void> delete(String id) async {
    final items = await load();
    final gone = items.where((e) => e.id == id).toList();
    items.removeWhere((e) => e.id == id);
    for (final e in gone) {
      await _deleteFile(e.imagePath);
    }
    await _write(items);
  }
 
  Future<void> clear() async {
    final items = await load();
    for (final e in items) {
      await _deleteFile(e.imagePath);
    }
    await _write([]);
  }
 
  Future<void> _deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
 