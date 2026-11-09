import '../../shared/widgets/blab_icon.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'edit_photo_screen.dart' show photoText, FrozenPhotoIcon;

Future<Uint8List> prepareProfilePhoto(Uint8List bytes) =>
    compute(_prepareSafely, bytes);
Uint8List _prepareSafely(Uint8List bytes) {
  try {
    return _prepare(bytes);
  } catch (_) {
    throw const FormatException('Unsupported or invalid image');
  }
}

Uint8List _prepare(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Invalid image size');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 40000000) {
    throw const FormatException('Invalid image dimensions');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  if (math.max(image.width, image.height) > 2048) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 2048 : null,
      height: image.height > image.width ? 2048 : null,
    );
  }
  image.exif = img.ExifData();
  image.textData = null;
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Crop coordinates refer to the normalized image, never screen pixels.
Uint8List cropProfilePhotoPixels(Uint8List bytes, Rect crop) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Invalid image');
  final side = crop.width
      .round()
      .clamp(1, math.min(image.width, image.height))
      .toInt();
  final result = img.copyCrop(
    image,
    x: crop.left.round().clamp(0, image.width - side).toInt(),
    y: crop.top.round().clamp(0, image.height - side).toInt(),
    width: side,
    height: side,
  );
  return Uint8List.fromList(
    img.encodeJpg(img.copyResize(result, width: 512, height: 512), quality: 90),
  );
}

Uint8List _crop(Map<String, Object> input) => cropProfilePhotoPixels(
  input['bytes']! as Uint8List,
  input['rect']! as Rect,
);

class CropProfilePhotoScreen extends StatefulWidget {
  const CropProfilePhotoScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<CropProfilePhotoScreen> createState() => _CropProfilePhotoScreenState();
}

class _CropProfilePhotoScreenState extends State<CropProfilePhotoScreen> {
  late final img.Image _image;
  double _zoom = 1, _startZoom = 1, _extent = 350;
  Offset _offset = Offset.zero,
      _startOffset = Offset.zero,
      _focal = Offset.zero;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _image = img.decodeJpg(widget.bytes)!;
  }

  double get _base => _extent / math.min(_image.width, _image.height);
  Offset _bounded(Offset value) {
    final scale = _base * _zoom;
    return Offset(
      value.dx.clamp(
        -(_image.width * scale - _extent) / 2,
        (_image.width * scale - _extent) / 2,
      ),
      value.dy.clamp(
        -(_image.height * scale - _extent) / 2,
        (_image.height * scale - _extent) / 2,
      ),
    );
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final scale = _base * _zoom;
    final side = (_extent - 24) / scale;
    final rect = Rect.fromLTWH(
      _image.width / 2 - _offset.dx / scale - side / 2,
      _image.height / 2 - _offset.dy / scale - side / 2,
      side,
      side,
    );
    try {
      final bytes = await compute(_crop, {'bytes': widget.bytes, 'rect': rect});
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(photoText(context, 'photoError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: BlabAppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            photoText(context, 'cropPhoto'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const BlabIcon(
              name: 'nav-arrow-left - 20',
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _extent = math.max(
                48,
                math.min(
                  constraints.maxWidth - 40,
                  constraints.maxHeight - 152,
                ),
              );
              _offset = _bounded(_offset);
              return Stack(
                children: [
                  Positioned(
                    top: math.min(
                      64,
                      math.max(0, constraints.maxHeight - _extent - 88),
                    ),
                    left: (constraints.maxWidth - _extent) / 2,
                    child: Semantics(
                      label: photoText(context, 'cropPhoto'),
                      child: GestureDetector(
                        key: const ValueKey('profile-crop-gesture'),
                        onScaleStart: _busy
                            ? null
                            : (d) {
                                _startZoom = _zoom;
                                _startOffset = _offset;
                                _focal = d.localFocalPoint;
                              },
                        onScaleUpdate: _busy
                            ? null
                            : (d) => setState(() {
                                _zoom = (_startZoom * d.scale).clamp(1, 5);
                                final ratio = _zoom / _startZoom;
                                final center = Offset(_extent / 2, _extent / 2);
                                _offset = _bounded(
                                  (d.localFocalPoint - center) -
                                      (_focal - center - _startOffset) * ratio,
                                );
                              }),
                        child: SizedBox.square(
                          dimension: _extent,
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Positioned(
                                  left:
                                      (_extent - _image.width * _base * _zoom) /
                                          2 +
                                      _offset.dx,
                                  top:
                                      (_extent -
                                              _image.height * _base * _zoom) /
                                          2 +
                                      _offset.dy,
                                  child: Image.memory(
                                    widget.bytes,
                                    width: _image.width * _base * _zoom,
                                    height: _image.height * _base * _zoom,
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    // Frozen Paper CTA: 32px from the viewport, not its inset.
                    bottom: 32,
                    child: SizedBox.square(
                      dimension: 56,
                      child: IconButton(
                        tooltip: photoText(context, 'confirmCrop'),
                        onPressed: _busy ? null : _confirm,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xfff88c5a),
                          foregroundColor: const Color(0xff46281c),
                        ),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const FrozenPhotoIcon(
                                icon: Icons.check,
                                color: Color(0xff46281c),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
