import 'dart:typed_data';

bool imageOcrSupported() => false;

Future<String> recogniseImageBytes(Uint8List bytes) async {
  throw const FormatException(
    'Receipt and scanned-PDF recognition is available on Android and iOS. '
    'Use a PDF with selectable text or paste the document text in this preview.',
  );
}
