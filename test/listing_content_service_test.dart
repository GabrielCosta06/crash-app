import 'package:crash_pad/services/listing_content_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ListingContentService();

  test('normalizes selected amenities and rules without duplicates', () {
    expect(
      service.normalizeSelection(<String>[
        '  Wi-Fi  ',
        'wi-fi',
        'Laundry',
        '  Quiet workspace   ',
      ]),
      <String>['Wi-Fi', 'Laundry', 'Quiet workspace'],
    );
  });

  test('rejects custom content that would create bad listing formatting', () {
    expect(service.validateCustomAmenity('TV'), 'Amenity is too short');
    expect(
      service.validateCustomAmenity('http://example.com'),
      'Do not add links, emails, or contact info here',
    );
    expect(
      service.validateCustomRule('Call +1 555 555 1212'),
      'Do not add phone numbers here',
    );
    expect(
      service.validateCustomRule('No <script> tags'),
      'Remove special formatting characters',
    );
    expect(
      service.validateCustomRule('123456'),
      'House rule must include readable text',
    );
  });

  test('accepts concise owner-provided amenities and house rules', () {
    expect(service.validateCustomAmenity('Blackout curtains'), isNull);
    expect(service.validateCustomRule('No food in sleeping rooms'), isNull);
  });
}
