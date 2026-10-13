import 'package:flutter/material.dart';
import '../services/cat_detection_service.dart';

class DetectionHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final int catId;
  final String catName;

  const DetectionHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.catId,
    required this.catName,
  });

  @override
  State<DetectionHistoryScreen> createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  List<DetectionLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await CatDetectionService.getHistory(widget.baseUrl, widget.catId);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  String _formatTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historija — ${widget.catName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Još nema zabilježenih provjera.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return ListTile(
                        leading: Icon(
                          log.catDetected ? Icons.check_circle : Icons.cancel,
                          color: log.catDetected ? Colors.green : Colors.red,
                        ),
                        title: Text(log.catDetected ? 'Mačka prepoznata' : 'Mačka nije prepoznata'),
                        subtitle: Text(_formatTime(log.detectedAt)),
                        trailing: Text('${(log.confidence * 100).toStringAsFixed(0)}%'),
                      );
                    },
                  ),
                ),
    );
  }
}