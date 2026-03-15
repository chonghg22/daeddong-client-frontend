import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';

final toiletRepositoryProvider = Provider((ref) => ToiletRepository());

final toiletListProvider = FutureProvider.family<List<ToiletModel>, ({double lat, double lng, double? distance})>(
  (ref, params) {
    final repo = ref.watch(toiletRepositoryProvider);
    return repo.getToiletList(
      latitude: params.lat,
      longitude: params.lng,
      distance: params.distance,
    );
  },
);
