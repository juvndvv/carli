import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final fileSharerProvider = Provider<FileSharer>((ref) => const SystemFileSharer());

abstract interface class FileSharer {
  Future<void> share({required String fileName, required List<int> bytes, required String mimeType, Rect? origin});
}

class SystemFileSharer implements FileSharer {
  const SystemFileSharer();

  @override
  Future<void> share({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    Rect? origin,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        sharePositionOrigin: origin,
      ),
    );
  }
}
