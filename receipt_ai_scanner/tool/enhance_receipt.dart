import 'dart:io';

import 'package:receipt_ai_scanner/src/receipt_image_preprocessor.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Kullanım: dart run tool/enhance_receipt.dart <girdi> <çıktı>',
    );
    exitCode = 64;
    return;
  }

  final input = File(arguments[0]);
  if (!await input.exists()) {
    stderr.writeln('Girdi görseli bulunamadı: ${input.path}');
    exitCode = 66;
    return;
  }

  final output = File(arguments[1]);
  await output.parent.create(recursive: true);
  final enhanced = enhanceReceiptImage(await input.readAsBytes());
  await output.writeAsBytes(enhanced, flush: true);
  stdout.writeln(output.absolute.path);
}
