import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:filmmaker_alerts/providers/tmdb_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RateLimitListener extends ConsumerWidget {
  final Widget child;

  const RateLimitListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<RateLimitEvent>>(tmdbRateLimitProvider, (previous, next) {
      next.whenData((event) {
        if (event.waitTimeSeconds > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Movie database service (TMDB) is busy. Waiting ${event.waitTimeSeconds}s... (Retry ${event.retryCount}/${event.maxRetries})',
              ),
              duration: Duration(seconds: event.waitTimeSeconds),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    });

    return child;
  }
}
