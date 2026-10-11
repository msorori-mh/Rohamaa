import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/donation_image_rules.dart';

void main() {
  group('DonationPhotoSet', () {
    test('no photos is different from photos that could not be signed', () {
      const none = DonationPhotoSet(total: 0, urls: <String>[]);
      expect(none.isEmpty, isTrue);
      expect(none.signingFailed, isFalse);
      expect(none.missing, 0);

      const failed = DonationPhotoSet(total: 3, urls: <String>[]);
      expect(failed.isEmpty, isFalse);
      expect(failed.signingFailed, isTrue);
      expect(failed.missing, 3);

      const partial = DonationPhotoSet(total: 3, urls: <String>['a', 'b']);
      expect(partial.isEmpty, isFalse);
      expect(partial.signingFailed, isFalse);
      expect(partial.missing, 1);
    });
  });

  group('leaving the donation result view', () {
    test('no confirmation when every photo is uploaded', () {
      expect(DonationImageRules.leaveWarningTitle(uploading: false, pending: 0), isNull);
      expect(DonationImageRules.leaveWarningMessage(uploading: false, pending: 0), isNull);
    });

    test('an upload in progress is confirmed, never blocked', () {
      expect(DonationImageRules.leaveWarningTitle(uploading: true, pending: 2), isNotNull);
      expect(
        DonationImageRules.leaveWarningMessage(uploading: true, pending: 2),
        contains('يستمر رفع الصور'),
      );
    });

    test('failed photos are confirmed with their count', () {
      expect(DonationImageRules.leaveWarningTitle(uploading: false, pending: 3), isNotNull);
      expect(
        DonationImageRules.leaveWarningMessage(uploading: false, pending: 3),
        contains('3'),
      );
      expect(
        DonationImageRules.leaveWarningMessage(uploading: false, pending: 1),
        contains('صورة واحدة'),
      );
    });

    test('a photo upload times out after one minute', () {
      expect(DonationImageRules.uploadTimeout, const Duration(seconds: 60));
    });
  });

  group('DonationImageRules', () {
    test('accepts JPEG, PNG and WebP by extension regardless of case', () {
      for (final name in ['a.jpg', 'a.JPEG', 'photo.final.png', 'x.WebP']) {
        expect(
          DonationImageRules.validate(fileName: name, sizeBytes: 1024),
          isNull,
          reason: name,
        );
      }
    });

    test('maps extensions and mime types to the upload content type', () {
      expect(DonationImageRules.contentTypeFor(fileName: 'a.jpg'), 'image/jpeg');
      expect(DonationImageRules.contentTypeFor(fileName: 'a.JPEG'), 'image/jpeg');
      expect(DonationImageRules.contentTypeFor(fileName: 'a.png'), 'image/png');
      expect(DonationImageRules.contentTypeFor(fileName: 'a.webp'), 'image/webp');
      expect(
        DonationImageRules.contentTypeFor(fileName: 'picked', mimeType: 'image/png'),
        'image/png',
      );
      expect(
        DonationImageRules.contentTypeFor(fileName: 'picked', mimeType: 'IMAGE/JPG'),
        'image/jpeg',
      );
      expect(DonationImageRules.contentTypeFor(fileName: 'picked'), isNull);
      expect(DonationImageRules.contentTypeFor(fileName: 'a.gif'), isNull);
    });

    test('rejects unsupported types by extension or mime type', () {
      expect(
        DonationImageRules.validate(fileName: 'a.gif', sizeBytes: 10),
        DonationImageRules.unsupportedTypeMessage,
      );
      expect(
        DonationImageRules.validate(fileName: 'a.heic', sizeBytes: 10, mimeType: 'image/heic'),
        DonationImageRules.unsupportedTypeMessage,
      );
      expect(
        DonationImageRules.validate(fileName: 'a.jpg', sizeBytes: 10, mimeType: 'application/pdf'),
        DonationImageRules.unsupportedTypeMessage,
      );
      expect(
        DonationImageRules.validate(fileName: 'no-extension', sizeBytes: 10),
        DonationImageRules.unsupportedTypeMessage,
      );
      expect(
        DonationImageRules.validate(fileName: 'trailing.', sizeBytes: 10),
        DonationImageRules.unsupportedTypeMessage,
      );
    });

    test('enforces the 5 MB bucket limit and rejects empty files', () {
      const limit = 5 * 1024 * 1024;
      expect(DonationImageRules.maxBytes, limit);
      expect(DonationImageRules.validate(fileName: 'a.jpg', sizeBytes: limit), isNull);
      expect(
        DonationImageRules.validate(fileName: 'a.jpg', sizeBytes: limit + 1),
        DonationImageRules.tooLargeMessage,
      );
      expect(
        DonationImageRules.validate(fileName: 'a.jpg', sizeBytes: 0),
        DonationImageRules.emptyFileMessage,
      );
    });

    test('stores a canonical extension for each content type', () {
      expect(DonationImageRules.extensionForContentType('image/jpeg'), 'jpg');
      expect(DonationImageRules.extensionForContentType('image/png'), 'png');
      expect(DonationImageRules.extensionForContentType('image/webp'), 'webp');
    });

    test('allows at most four photos per donation', () {
      expect(DonationImageRules.maxImages, 4);
      expect(DonationImageRules.remainingSlots(0), 4);
      expect(DonationImageRules.remainingSlots(3), 1);
      expect(DonationImageRules.remainingSlots(4), 0);
      expect(DonationImageRules.remainingSlots(9), 0);
    });

    test('messages are Arabic and never expose technical names', () {
      for (final message in [
        DonationImageRules.unsupportedTypeMessage,
        DonationImageRules.tooLargeMessage,
        DonationImageRules.emptyFileMessage,
        DonationImageRules.tooManyMessage,
      ]) {
        expect(message.contains(RegExp(r'[؀-ۿ]')), isTrue);
        expect(message.toLowerCase().contains('mime'), isFalse);
      }
    });
  });
}
