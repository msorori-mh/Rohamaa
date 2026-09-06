import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class DonationImageRepository {
  DonationImageRepository(this._client);
  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  Future<String> upload({
    required String donationId,
    required Uint8List bytes,
    required String extension,
    int sortOrder = 0,
  }) async {
    final safeExt = extension.toLowerCase().replaceAll('.', '');
    final path = '$_userId/$donationId/${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    await _client.storage.from('donation-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );
    await _client.from('donation_images').insert({
      'donation_id': donationId,
      'storage_path': path,
      'sort_order': sortOrder,
    });
    return path;
  }

  Future<String> signedUrl(String path) {
    return _client.storage.from('donation-images').createSignedUrl(path, 600);
  }
}
