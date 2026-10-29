import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdfrx/pdfrx.dart';
import 'ocr_image_stub.dart' if (dart.library.io) 'ocr_image_io.dart' as ocr;

/// Local document extraction. Financial facts still go through capture review.
class DocumentTextService {
  const DocumentTextService();
  static const maxBytes = 15 * 1024 * 1024;
  static const maxPages = 40;
  static int _documentSequence = 0;

  Future<String> readReceipt(Uint8List bytes) async {
    _validateSize(bytes);
    if (!ocr.imageOcrSupported()) {
      throw const FormatException(
        'Receipt recognition is available on Android and iOS. '
        'Paste the receipt text in this preview.',
      );
    }
    final normalized = await _normaliseReceipt(bytes);
    final result = await ocr.recogniseImageBytes(normalized);
    if (result.trim().isEmpty) {
      throw const FormatException(
        'No receipt text was found. Try a clearer photo or enter the details.',
      );
    }
    return result;
  }

  Future<String> readPdf(
    Uint8List bytes, {
    String? password,
    void Function(int completedPages, int totalPages)? onProgress,
  }) async {
    _validateSize(bytes);
    if (!String.fromCharCodes(bytes.take(1024)).contains('%PDF-')) {
      throw const FormatException('Choose a valid PDF document.');
    }
    PdfDocument? document;
    var passwordAttempted = false;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openData(
        bytes,
        sourceName:
            'pennywise-import-${DateTime.now().microsecondsSinceEpoch}-${_documentSequence++}',
        // A wrong password is offered once. Returning it forever loops the API.
        passwordProvider: () {
          if (passwordAttempted) return null;
          passwordAttempted = true;
          return password;
        },
      );
      if (document.pages.isEmpty || document.pages.length > maxPages) {
        throw const FormatException(
          'Import a PDF containing between 1 and 40 pages. Split longer statements first.',
        );
      }
      final pages = <String>[];
      onProgress?.call(0, document.pages.length);
      for (var index = 0; index < document.pages.length; index++) {
        final page = document.pages[index];
        var text = (await page.loadText())?.fullText ?? '';
        if (text.trim().isEmpty) {
          if (!ocr.imageOcrSupported()) {
            throw FormatException(
              'Page ${index + 1} has no selectable text. Scanned-PDF recognition '
              'requires Android or iOS; paste the statement text in this preview.',
            );
          }
          text = await _readScannedPage(page, index + 1);
        }
        if (text.trim().isEmpty) {
          throw FormatException(
            'Page ${index + 1} could not be read. Use a clearer scan or paste its text. No partial statement was imported.',
          );
        }
        pages.add(text);
        onProgress?.call(index + 1, document.pages.length);
      }
      return pages.join('\n\n');
    } on PdfPasswordException {
      throw FormatException(
        password == null || password.isEmpty
            ? 'This PDF needs a password. Enter it to read the statement.'
            : 'The PDF password was not accepted. Check it and try again.',
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The PDF could not be read. Check the file and its password, or paste the document text.',
      );
    } finally {
      await document?.dispose();
    }
  }

  static void _validateSize(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Choose a nonempty document smaller than 15 MB.',
      );
    }
  }

  Future<String> _readScannedPage(PdfPage page, int pageNumber) async {
    final width = page.width, height = page.height;
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        width > 20000 ||
        height > 20000 ||
        width / height > 8 ||
        height / width > 8) {
      throw FormatException(
        'Page $pageNumber is too large or unusually shaped. Export it as smaller pages before scanning.',
      );
    }
    final scale = math.min(1600 / width, 2000 / height);
    final imageWidth = math.max(1, (width * scale).round());
    final imageHeight = math.max(1, (height * scale).round());
    // One bounded bitmap at a time: at most 1600x2000 pixels, never whole-document rendering.
    final image = await page.render(
      fullWidth: imageWidth.toDouble(),
      fullHeight: imageHeight.toDouble(),
      width: imageWidth,
      height: imageHeight,
      backgroundColor: 0xffffffff,
    );
    if (image == null) {
      throw FormatException('Page $pageNumber could not be rendered.');
    }
    ui.Image? decoded;
    try {
      decoded = await image.createImage();
      final png = await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw FormatException(
          'Page $pageNumber could not be prepared for recognition.',
        );
      }
      return await ocr.recogniseImageBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    } finally {
      decoded?.dispose();
      image.dispose();
    }
  }

  Future<Uint8List> _normaliseReceipt(Uint8List bytes) async {
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    if (!isJpeg && !isPng) {
      throw const FormatException('Choose a JPG or PNG receipt image.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width, height = descriptor.height;
      if (width <= 0 ||
          height <= 0 ||
          width > 20000 ||
          height > 20000 ||
          width * height > 24000000) {
        throw const FormatException(
          'This image is too large to scan safely. Resize it below 24 megapixels or crop the receipt.',
        );
      }
      final scale = math.min(1.0, 2400 / math.max(width, height));
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('The receipt image could not be decoded.');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
