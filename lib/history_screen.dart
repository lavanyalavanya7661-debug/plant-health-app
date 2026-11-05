import 'dart:io';
 
import 'package:flutter/material.dart';
 
import 'history_store.dart';
import 'main.dart' show ResultSheet;
 
/// List of past scans. Tap to reopen the result, swipe to delete.
class HistoryScreen extends StatefulWidget {
  final HistoryStore store;
  const HistoryScreen({super.key, required this.store});
 
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}
 
class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry>? _items;
 
  @override
  void initState() {
    super.initState();
    _reload();
  }
 
  Future<void> _reload() async {
    final items = await widget.store.load();
    if (mounted) setState(() => _items = items);
  }
 
  String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}-${two(t.month)}-${t.year}  ${two(t.hour)}:${two(t.minute)}';
  }
 
  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('All saved scans and photos will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.clear();
      _reload();
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan history'),
        actions: [
          if (items != null && items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No scans yet'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final top = e.top;
                    final title = top.isOther
                        ? 'Not one of my crops'
                        : top.isHealthy
                            ? '${top.crop} – healthy'
                            : '${top.crop} – ${top.condition}';
                    return Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await widget.store.delete(e.id);
                        _reload();
                      },
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(e.imagePath),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image)),
                        ),
                        title: Text(title),
                        subtitle: Text(
                            '${(top.confidence * 100).toStringAsFixed(0)}%  ·  ${_when(e.time)}'),
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => ResultSheet(
                              image: File(e.imagePath),
                              predictions: e.predictions),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}