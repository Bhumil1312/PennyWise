import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

bool imageOcrSupported() => Platform.isAndroid || Platform.isIOS;

/// ML Kit's native API needs a private temporary image file. Never retain it.
Future<String> recogniseImageBytes(Uint8List bytes) async {
  if (!imageOcrSupported()) {
    throw const FormatException(
      'On-device image recognition is available on Android and iOS. '
      'Use a PDF with selectable text or paste the document text on this device.',
    );
  }
  final parent = await getTemporaryDirectory();
  final directory = await parent.createTemp('pennywise-ocr-');
  final file = File('${directory.path}/page.png');
  TextRecognizer? recognizer;
  try {
    await file.writeAsBytes(bytes, flush: true);
    recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    return result.text;
  } finally {
    // Do not place input bytes, extracted text, paths or errors in logs.
    try {
      await recognizer?.close();
    } finally {
      if (await file.exists()) await file.delete();
      // This is the unique directory created above and contains only our page.
      if (await directory.exists()) await directory.delete();
    }
  }
}
