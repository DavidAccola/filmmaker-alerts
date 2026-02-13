import 'package:hive/hive.dart';
import '../models/collection_order.dart';

/// Repository for managing custom movie order within collections
class CollectionOrderRepository {
  final Box<CollectionOrder> _box;

  CollectionOrderRepository(this._box);

  /// Gets the custom order for a collection, or null if not set
  CollectionOrder? getOrder(int collectionId) {
    return _box.get(collectionId.toString());
  }

  /// Gets the ordered movie IDs for a collection
  /// Returns null if no custom order has been set
  List<int>? getMovieOrder(int collectionId) {
    final order = getOrder(collectionId);
    return order?.movieIds;
  }

  /// Sets the custom movie order for a collection
  Future<void> setMovieOrder(int collectionId, List<int> movieIds) async {
    final existing = getOrder(collectionId);
    
    if (existing != null) {
      existing.movieIds = movieIds;
      await existing.save();
    } else {
      final newOrder = CollectionOrder(
        collectionId: collectionId,
        movieIds: movieIds,
      );
      await _box.put(collectionId.toString(), newOrder);
    }
  }

  /// Clears the custom order for a collection (reverts to default)
  Future<void> clearOrder(int collectionId) async {
    await _box.delete(collectionId.toString());
  }

  /// Clears all collection orders
  Future<void> clearAll() async {
    await _box.clear();
  }
}
