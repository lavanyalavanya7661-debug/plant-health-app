import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'care_tips.dart';
import 'classifier.dart';
import 'history_screen.dart';
import 'history_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'auth_service.dart';
import 'result_mailer.dart';

/// Below this confidence we ask the user to retake the photo.
const double kConfidenceThreshold = 0.80;

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  cameras = await availableCameras();

  runApp(const PlantScannerApp());
}


class PlantScannerApp extends StatelessWidget {
  const PlantScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Health Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _camera;
  final PlantClassifier _classifier = PlantClassifier();
  final ImagePicker _picker = ImagePicker();
  final HistoryStore _history = HistoryStore();

  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _classifier.load();
      if (cameras.isNotEmpty) {
        final controller = CameraController(
          cameras.first, // back camera on most phones
          ResolutionPreset.high,
          enableAudio: false,
        );
        await controller.initialize();
        _camera = controller;
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Startup problem: $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _classifier.close();
    super.dispose();
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    final shot = await camera.takePicture();
    await _scan(File(shot.path));
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) await _scan(File(picked.path));
  }

    Future<void> _scan(File file) async {
    setState(() => _busy = true);
    try {
      final predictions = await _classifier.classify(file);
      await _history.add(file, predictions);
      if (!mounted) return;

      // Email the result to the signed-in user.
      final mailer = ResultMailer();
      final email = await mailer.emailFor(context);
      if (email != null) {
        mailer
            .sendResult(email, predictions, threshold: kConfidenceThreshold)
            .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Result sent to $email')),
            );
          }
        }).catchError((e) {
          debugPrint('Email failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not email the result')),
            );
          }
        });
      }
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ResultSheet(image: file, predictions: predictions),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center),
      )));
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_camera != null) CameraPreview(_camera!),
          // Framing guide
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
  top: 36,
  right: 8,
  child: IconButton(
    color: Colors.white,
    tooltip: 'Sign out',
    icon: const Icon(Icons.logout),
    onPressed: () => AuthService().signOut(),
  ),
),
          const Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Text(
              'Fill the frame with one leaf\nin good light',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 36,
                  color: Colors.white,
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.green, width: 5),
                    ),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : null,
                  ),
                ),
                IconButton(
  iconSize: 36,
  color: Colors.white,
  tooltip: 'Scan history',
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HistoryScreen(store: _history)),
  ),
  icon: const Icon(Icons.history),
),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultSheet extends StatelessWidget {
  final File image;
  final List<Prediction> predictions;

  const ResultSheet({super.key, required this.image, required this.predictions});

  @override
  Widget build(BuildContext context) {
    final top = predictions.first;
    final confident = top.confidence >= kConfidenceThreshold;
    final percent = (top.confidence * 100).toStringAsFixed(0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(image, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            if (confident) ...[
              Row(
                children: [
                  Icon(
                    top.isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: top.isHealthy ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      top.isHealthy ? 'Looks healthy' : 'Likely: ${top.condition}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${top.crop}  ·  $percent% confidence'),
              const SizedBox(height: 16),
              Text(careTipFor(top.condition)),
            ] else ...[
              Text(
                "I'm not sure about this one",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try again: move closer to a single leaf, use daylight, keep the '
                'leaf flat and the photo sharp. The app only knows common crops '
                '(tomato, potato, pepper, corn).',
              ),
            ],
            const SizedBox(height: 16),
            Text('Other possibilities',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final p in predictions.skip(confident ? 1 : 0))
              Text('${p.crop} – ${p.condition}  '
                  '(${(p.confidence * 100).toStringAsFixed(0)}%)'),
            const SizedBox(height: 12),
            const Text(
              'This is an AI estimate from a photo, not a certain diagnosis.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}