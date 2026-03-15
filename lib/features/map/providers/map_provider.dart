import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';

class MapState {
  final List<ToiletModel> toiletList;
  final bool isLoading;
  final String? error;
  final ToiletModel? selectedToilet;

  const MapState({
    this.toiletList = const [],
    this.isLoading = false,
    this.error,
    this.selectedToilet,
  });

  MapState copyWith({
    List<ToiletModel>? toiletList,
    bool? isLoading,
    String? error,
    ToiletModel? selectedToilet,
    bool clearError = false,
    bool clearSelectedToilet = false,
  }) {
    return MapState(
      toiletList: toiletList ?? this.toiletList,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedToilet: clearSelectedToilet ? null : (selectedToilet ?? this.selectedToilet),
    );
  }
}

class MapNotifier extends StateNotifier<MapState> {
  final ToiletRepository _repository;

  MapNotifier(this._repository) : super(const MapState());

  Future<void> loadToilets(double lat, double lng, double distance) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getToiletList(
        latitude: lat,
        longitude: lng,
        distance: distance,
      );
      state = state.copyWith(toiletList: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectToilet(ToiletModel toilet) {
    state = state.copyWith(selectedToilet: toilet);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedToilet: true);
  }
}

final toiletRepositoryProvider = Provider((ref) => ToiletRepository());

final mapProvider = StateNotifierProvider<MapNotifier, MapState>(
  (ref) => MapNotifier(ref.watch(toiletRepositoryProvider)),
);
