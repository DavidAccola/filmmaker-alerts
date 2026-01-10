import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JustWatch Service - Property 9: JustWatch Integration', () {
    test('Property 9: StreamingType enum has all required types', () {
      // Arrange & Act & Assert
      expect(StreamingType.subscription, isNotNull);
      expect(StreamingType.rent, isNotNull);
      expect(StreamingType.buy, isNotNull);
      expect(StreamingType.free, isNotNull);
    });

    test('Property 9: StreamingOption can be created with all required fields', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '8',
        providerName: 'Netflix',
        logoPath: 'https://example.com/netflix.png',
        type: StreamingType.subscription,
        price: null,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.providerId, equals('8'));
      expect(option.providerName, equals('Netflix'));
      expect(option.type, equals(StreamingType.subscription));
      expect(option.deepLink, equals('https://www.justwatch.com/us/movie/550'));
    });

    test('Property 9: StreamingOption supports subscription type', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '8',
        providerName: 'Netflix',
        type: StreamingType.subscription,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.type, equals(StreamingType.subscription));
    });

    test('Property 9: StreamingOption supports rent type', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '2',
        providerName: 'Amazon Prime Video',
        type: StreamingType.rent,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.type, equals(StreamingType.rent));
    });

    test('Property 9: StreamingOption supports buy type', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '2',
        providerName: 'Amazon Prime Video',
        type: StreamingType.buy,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.type, equals(StreamingType.buy));
    });

    test('Property 9: StreamingOption supports free type', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '15',
        providerName: 'Tubi',
        type: StreamingType.free,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.type, equals(StreamingType.free));
    });

    test('Property 9: Work can contain streaming options', () {
      // Arrange
      final streamingOptions = [
        StreamingOption(
          providerId: '8',
          providerName: 'Netflix',
          type: StreamingType.subscription,
          deepLink: 'https://www.justwatch.com/us/movie/550',
        ),
        StreamingOption(
          providerId: '2',
          providerName: 'Amazon Prime Video',
          type: StreamingType.rent,
          deepLink: 'https://www.justwatch.com/us/movie/550',
        ),
      ];

      // Act
      final work = Work(
        tmdbId: 550,
        title: 'Fight Club',
        type: WorkType.movie,
        streamingOptions: streamingOptions,
      );

      // Assert
      expect(work.streamingOptions, hasLength(2));
      expect(work.streamingOptions[0].providerName, equals('Netflix'));
      expect(work.streamingOptions[1].providerName, equals('Amazon Prime Video'));
    });

    test('Property 9: Work streaming options can be empty', () {
      // Arrange & Act
      final work = Work(
        tmdbId: 550,
        title: 'Fight Club',
        type: WorkType.movie,
        streamingOptions: [],
      );

      // Assert
      expect(work.streamingOptions, isEmpty);
    });

    test('Property 9: Multiple streaming options can have different types', () {
      // Arrange
      final options = [
        StreamingOption(
          providerId: '8',
          providerName: 'Netflix',
          type: StreamingType.subscription,
          deepLink: 'https://www.justwatch.com/us/movie/550',
        ),
        StreamingOption(
          providerId: '2',
          providerName: 'Amazon Prime Video',
          type: StreamingType.rent,
          deepLink: 'https://www.justwatch.com/us/movie/550',
        ),
        StreamingOption(
          providerId: '15',
          providerName: 'Tubi',
          type: StreamingType.free,
          deepLink: 'https://www.justwatch.com/us/movie/550',
        ),
      ];

      // Act & Assert
      expect(options[0].type, equals(StreamingType.subscription));
      expect(options[1].type, equals(StreamingType.rent));
      expect(options[2].type, equals(StreamingType.free));
    });

    test('Property 9: StreamingOption preserves provider information', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '8',
        providerName: 'Netflix',
        logoPath: 'https://example.com/netflix.png',
        type: StreamingType.subscription,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.providerId, equals('8'));
      expect(option.providerName, equals('Netflix'));
      expect(option.logoPath, equals('https://example.com/netflix.png'));
    });

    test('Property 9: StreamingOption handles missing logo path', () {
      // Arrange & Act
      final option = StreamingOption(
        providerId: '999',
        providerName: 'Unknown Provider',
        type: StreamingType.subscription,
        deepLink: 'https://www.justwatch.com/us/movie/550',
      );

      // Assert
      expect(option.logoPath, isNull);
      expect(option.providerName, equals('Unknown Provider'));
    });
  });
}
