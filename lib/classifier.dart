import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class Prediction {
  final String rawLabel;
  final double confidence;

  const Prediction(this.rawLabel, this.confidence);

  String get crop => _clean(rawLabel.split('___').first);

  String get condition {
    final parts = rawLabel.split('___');
    return parts.length > 1 ? _clean(parts[1]) : 'Unknown';
  }

  bool get isHealthy => condition.toLowerCase() == 'healthy';

  bool get isOther => rawLabel.toLowerCase().startsWith('other');

  static String _clean(String s) => s.replaceAll('_', ' ').trim();
}

class PlantClassifier {
  late final Interpreter _interpreter;
  late final List<String> _labels;
  late final int _inputHeight;
  late final int _inputWidth;

  Future<void> load() async {
    // Load the NEW model.
    _interpreter = await Interpreter.fromAsset(
      'assets/models/plant_disease_model.tflite',
    );

    // Load labels generated during the SAME Colab training run.
    final raw = await rootBundle.loadString(
      'assets/data/plant_disease_labels.json',
    );

    _labels = (jsonDecode(raw) as List)
        .map((e) => e.toString())
        .toList();

    // Read model input dimensions.
    final inputTensor = _interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;

    if (inputShape.length != 4 || inputShape[3] != 3) {
      throw Exception(
        'Unexpected model input shape: $inputShape',
      );
    }

    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];

    // Check that labels match the model output.
    final outputTensor = _interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;

    if (outputShape.isEmpty ||
        outputShape.last != _labels.length) {
      throw Exception(
        'Model output shape $outputShape does not match '
        '${_labels.length} labels.',
      );
    }

    ('Plant disease model loaded successfully.');
    ('Input shape: $inputShape');
    ('Output shape: $outputShape');
    ('Number of labels: ${_labels.length}');
  }

  Future<List<Prediction>> classify(
    File file, {
    int topK = 3,
  }) async {
    final bytes = await file.readAsBytes();

    var image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Could not read the image.');
    }

    image = img.bakeOrientation(image);

    final resized = img.copyResize(
      image,
      width: _inputWidth,
      height: _inputHeight,
    );

    // The Colab MobileNetV2 model has a Rescaling layer
    // inside the model. Supply RGB pixel values from 0 to 255.
    final input = [
      List.generate(
        _inputHeight,
        (y) => List.generate(
          _inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);

            return <double>[
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    ];

    final output = [
      List<double>.filled(_labels.length, 0.0),
    ];

    _interpreter.run(input, output);

    final scores = output[0];

    final order = List.generate(
      scores.length,
      (i) => i,
    )..sort(
        (a, b) => scores[b].compareTo(scores[a]),
      );

    return order
        .take(topK.clamp(1, scores.length))
        .map(
          (i) => Prediction(
            _labels[i],
            scores[i],
          ),
        )
        .toList();
  }

  void close() {
    _interpreter.close();
  }
}