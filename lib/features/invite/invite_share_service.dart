import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const _channel = MethodChannel('blab/invite');

Future<bool> shareInviteText(String text) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return await _channel.invokeMethod<bool>('shareInvite', {'text': text}) ??
        false;
  }
  final result = await SharePlus.instance.share(ShareParams(text: text));
  return result.status != ShareResultStatus.dismissed;
}
