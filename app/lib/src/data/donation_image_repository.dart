import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/donation_image_rules.dart';

/// Thrown before any network call when a photo breaks the bucket rules.
/// [message] is Arabic copy that can be shown to the person as is.
class DonationImageRejected implements Exception {
  const DonationImageRejected(this.message);

  final String message;

  @override
  String toString() => 'DonationImageRejected';
}

class DonationImageRepository {
  DonationImageRepository(this._client);
  final SupabaseClient _client;

  static const String _bucket = 'donation-images';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  /// Number of photos already attached to [donationId].
  Future<int> imageCount(String donationId) async {
    final rows = await _client
        .from('donation_images')
        .select('id')
        .eq('donation_id', donationId);
    return (rows as List).length;
  }

  /// Uploads one photo and links it to [donationId].
  ///
  /// The photo is validated first (type, size, at most
  /// [DonationImageRules.maxImages] per donation). When the photo was stored
  /// but could not be linked, the stored object is removed again so that a
  /// retry does not leave orphans behind.
  ///
  /// Pass the picked file's [fileName] (and [mimeType] when known). The older
  /// [extension] argument is still accepted for callers that only know the
  /// extension.
  Future<String> upload({
    required String donationId,
    required Uint8List bytes,
    String? fileName,
    String? extension,
    String? mimeType,
    int sortOrder = 0,
  }) async {
    final name = fileName ?? 'photo.${(extension ?? '').replaceAll('.', '')}';
    final problem = DonationImageRules.validate(
      fileName: name,
      sizeBytes: bytes.length,
      mimeType: mimeType,
    );
    if (problem != null) throw DonationImageRejected(problem);
    final contentType = DonationImageRules.contentTypeFor(
      fileName: name,
      mimeType: mimeType,
    );
    if (contentType == null) {
      throw const DonationImageRejected(
        DonationImageRules.unsupportedTypeMessage,
      );
    }
    if (await imageCount(donationId) >= DonationImageRules.maxImages) {
      throw const DonationImageRejected(DonationImageRules.tooManyMessage);
    }

    final storedExtension =
        DonationImageRules.extensionForContentType(contentType);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$_userId/$donationId/${stamp}_$sortOrder.$storedExtension';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    try {
      await _client.from('donation_images').insert({
        'donation_id': donationId,
        'storage_path': path,
        'sort_order': sortOrder,
      });
    } catch (_) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Best effort only: the original failure is what the caller needs.
      }
      rethrow;
    }
    return path;
  }
}
