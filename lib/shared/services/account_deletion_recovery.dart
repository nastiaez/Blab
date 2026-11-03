import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable opaque receipt, never a password, bearer token or deletion authority.
class AccountDeletionRecovery {
  AccountDeletionRecovery({this.removeMarker});
  final Future<bool> Function(SharedPreferences, String)? removeMarker;
  static const storageKey = 'account_deletion_pending:v1';
  Future<bool>? _reconciling;
  Future<({String owner, String receipt})?> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final owner = value['owner'], receipt = value['receipt'];
      if (owner is String &&
          receipt is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(receipt)) {
        return (owner: owner, receipt: receipt);
      }
    } catch (_) {}
    return null;
  }

  Future<String> begin(String owner) async {
    final old = await pending();
    if (old?.owner == owner) return old!.receipt;
    final random = Random.secure();
    final receipt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode({'owner': owner, 'receipt': receipt}),
    )) {
      await prefs.reload();
      throw StateError('deletion_receipt_not_saved');
    }
    return receipt;
  }

  Future<void> forget({required String owner, required String receipt}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['owner'] != owner || value['receipt'] != receipt) return;
    if (!await (removeMarker?.call(prefs, storageKey) ??
        prefs.remove(storageKey))) {
      await prefs.reload();
      throw StateError('deletion_receipt_removal_failed');
    }
  }

  Future<bool> reconcile({
    required String? Function() currentOwner,
    required Future<bool> Function(String) confirmed,
    required Future<void> Function(String owner) erase,
  }) {
    return _reconciling ??= _run(
      currentOwner: currentOwner,
      confirmed: confirmed,
      erase: erase,
    ).whenComplete(() => _reconciling = null);
  }

  Future<bool> _run({
    required String? Function() currentOwner,
    required Future<bool> Function(String) confirmed,
    required Future<void> Function(String owner) erase,
  }) async {
    final record = await pending();
    if (record == null) return false;
    bool sameOwner() =>
        currentOwner() == null || currentOwner() == record.owner;
    if (!sameOwner()) return false;
    // Unknown/offline outcomes retain both account data and the durable marker.
    if (!await confirmed(record.receipt) || !sameOwner()) return false;
    await erase(record.owner);
    await forget(owner: record.owner, receipt: record.receipt);
    return true;
  }
}
