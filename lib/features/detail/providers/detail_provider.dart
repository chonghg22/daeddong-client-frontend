import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';
import 'package:daeddong/features/map/providers/map_provider.dart';

class DetailState {
  final ToiletModel? toilet;
  final bool isLoading;
  final String? error;

  const DetailState({
    this.toilet,
    this.isLoading = false,
    this.error,
  });

  DetailState copyWith({
    ToiletModel? toilet,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DetailState(
      toilet: toilet ?? this.toilet,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DetailNotifier extends StateNotifier<DetailState> {
  final ToiletRepository _repository;

  DetailNotifier(this._repository) : super(const DetailState());

  Future<void> loadToiletDetail(int seq) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final toilet = await _repository.getToiletDetail(seq: seq);
      state = state.copyWith(toilet: toilet, isLoading: false);
    } catch (e) {
      debugPrint('[DetailProvider] loadToiletDetail 오류: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final detailProvider =
    StateNotifierProvider.autoDispose<DetailNotifier, DetailState>(
  (ref) => DetailNotifier(ref.watch(toiletRepositoryProvider)),
);
