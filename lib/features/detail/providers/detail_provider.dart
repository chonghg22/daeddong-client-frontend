import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';
import 'package:daeddong/features/map/providers/map_provider.dart';

class DetailState {
  final ToiletModel? toilet;
  final bool isLoading;
  final String? error;
  final bool isFavorite;

  const DetailState({
    this.toilet,
    this.isLoading = false,
    this.error,
    this.isFavorite = false,
  });

  DetailState copyWith({
    ToiletModel? toilet,
    bool? isLoading,
    String? error,
    bool? isFavorite,
    bool clearError = false,
  }) {
    return DetailState(
      toilet: toilet ?? this.toilet,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class DetailNotifier extends StateNotifier<DetailState> {
  final ToiletRepository _repository;

  static const _favoritesKey = 'favorites';

  DetailNotifier(this._repository) : super(const DetailState());

  Future<void> loadToiletDetail(int seq) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final toilet = await _repository.getToiletDetail(seq: seq);
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      state = state.copyWith(
        toilet: toilet,
        isLoading: false,
        isFavorite: favorites.contains(seq.toString()),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleFavorite(int seq) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    final seqStr = seq.toString();
    if (favorites.contains(seqStr)) {
      favorites.remove(seqStr);
    } else {
      favorites.add(seqStr);
    }
    await prefs.setStringList(_favoritesKey, favorites);
    state = state.copyWith(isFavorite: !state.isFavorite);
  }
}

final detailProvider = StateNotifierProvider.autoDispose<DetailNotifier, DetailState>(
  (ref) => DetailNotifier(ref.watch(toiletRepositoryProvider)),
);
