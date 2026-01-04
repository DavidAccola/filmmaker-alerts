import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:filmmaker_alerts/providers/providers.dart';

final tmdbRateLimitProvider = StreamProvider<RateLimitEvent>((ref) {
  final service = ref.watch(tmdbServiceProvider);
  return service.onRateLimit;
});
