import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/chat_service.dart';
import '../widgets/gallery_picker_screen.dart';

class ChatImagePicker {
  const ChatImagePicker();

  /// Opens the gallery sheet, which also owns the camera tile — the same
  /// sheet returns a file whether the source was a picked photo or a fresh
  /// camera capture, so the caller doesn't need to know which.
  Future<PickedChatImage?> pick(BuildContext context) async {
    final file = await showGalleryPickerSheet(context);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedChatImage(
      bytes: bytes,
      mimeType: _mimeTypeFromName(file.path),
      fileName: file.uri.pathSegments.last,
    );
  }
}

String _mimeTypeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

final chatImagePickerProvider = Provider<ChatImagePicker>(
  (ref) => const ChatImagePicker(),
);
