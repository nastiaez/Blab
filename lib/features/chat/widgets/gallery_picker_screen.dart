import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Custom in-app photo grid (WhatsApp/Telegram-style), replacing the Android
/// system photo picker so gallery selection matches the app's own look.
///
/// Presented as a draggable bottom sheet — chat stays visible (dimmed)
/// behind it, and dragging it down (or tapping the scrim) dismisses it,
/// matching WhatsApp/Telegram's attach-gallery sheet.
Future<File?> showGalleryPickerSheet(BuildContext context) {
  return showModalBottomSheet<File>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.78;
      return SizedBox(
        height: sheetHeight,
        child: const SafeArea(top: false, child: _GalleryPickerSheet()),
      );
    },
  );
}

enum _LoadState { loading, denied, empty, ready }

class _GalleryPickerSheet extends StatefulWidget {
  const _GalleryPickerSheet();

  @override
  State<_GalleryPickerSheet> createState() => _GalleryPickerSheetState();
}

class _GalleryPickerSheetState extends State<_GalleryPickerSheet> {
  static const _pageSize = 90;

  _LoadState _state = _LoadState.loading;
  AssetPathEntity? _recentAlbum;
  final List<AssetEntity> _assets = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!permission.hasAccess) {
      setState(() => _state = _LoadState.denied);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (!mounted) return;
    if (albums.isEmpty) {
      setState(() => _state = _LoadState.empty);
      return;
    }
    _recentAlbum = albums.first;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final album = _recentAlbum;
    if (album == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    final page = _assets.length ~/ _pageSize;
    final next = await album.getAssetListPaged(page: page, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets.addAll(next);
      _hasMore = next.length == _pageSize;
      _loadingMore = false;
      _state = _assets.isEmpty ? _LoadState.empty : _LoadState.ready;
    });
  }

  Future<void> _select(AssetEntity asset) async {
    final file = await asset.file;
    if (!mounted) return;
    if (file == null) return;
    Navigator.of(context).pop(file);
  }

  Future<void> _openCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 2400,
    );
    if (!mounted || picked == null) return;
    Navigator.of(context).pop(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DragHandle(),
        _Header(title: context.l10n.photos),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        );
      case _LoadState.denied:
        return _PermissionDenied(
          onOpenSettings: () => PhotoManager.openSetting(),
          onOpenCamera: _openCamera,
        );
      case _LoadState.empty:
        return Center(
          child: Text(
            context.l10n.noPhotosFound,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        );
      case _LoadState.ready:
        return GridView.builder(
          key: const ValueKey('gallery-picker-grid'),
          controller: _scrollController,
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: _assets.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _CameraTile(
                key: const ValueKey('gallery-picker-camera-tile'),
                onTap: _openCamera,
              );
            }
            final asset = _assets[i - 1];
            return _GalleryTile(
              key: ValueKey('gallery-tile-${asset.id}'),
              asset: asset,
              onTap: () => _select(asset),
            );
          },
        );
    }
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10, bottom: 4),
      child: SizedBox(
        width: 40,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Positioned(
            left: 4,
            child: IconButton(
              key: const ValueKey('gallery-picker-close'),
              tooltip: context.l10n.cancel,
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({
    required this.onOpenSettings,
    required this.onOpenCamera,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: Colors.white54,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.photoAccessNeeded,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.photoAccessNeededBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('gallery-picker-open-settings'),
              style: FilledButton.styleFrom(backgroundColor: BlabColors.brand),
              onPressed: onOpenSettings,
              child: Text(context.l10n.openSettings),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('gallery-picker-camera-fallback'),
              onPressed: onOpenCamera,
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white70,
              ),
              label: const Text(
                'Camera',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Center(
          child: Icon(Icons.photo_camera, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({super.key, required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<Uint8List?>(
        future: asset.thumbnailDataWithSize(const ThumbnailSize(240, 240)),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const ColoredBox(color: Color(0xFF1A1A1A));
          }
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      ),
    );
  }
}
