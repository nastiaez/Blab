import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/services/chat_service.dart';

enum ChatImageSource { gallery, camera }

class ChatImagePicker {
  ChatImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedChatImage?> pick(ChatImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == ChatImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2400,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedChatImage(
      bytes: bytes,
      mimeType: picked.mimeType ?? _mimeTypeFromName(picked.name),
      fileName: picked.name,
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
  (ref) => ChatImagePicker(),
);
