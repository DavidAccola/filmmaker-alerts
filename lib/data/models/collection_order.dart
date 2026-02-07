import 'package:hive/hive.dart';

part 'collection_order.g.dart';

/// Stores the custom movie order for a collection
@HiveType(typeId: 49)
class CollectionOrder extends HiveObject {
  @HiveField(0)
  late int collectionId;
  
  /// List of movie IDs in the user's preferred order
  @HiveField(1)
  late List<int> movieIds;
  
  CollectionOrder({
    required this.collectionId,
    List<int>? movieIds,
  }) : movieIds = movieIds ?? [];
}
