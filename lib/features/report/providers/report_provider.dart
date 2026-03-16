import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daeddong/data/repositories/toilet_repository.dart';
import 'package:daeddong/features/map/providers/map_provider.dart';

class ReportState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const ReportState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  ReportState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    bool clearError = false,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final ToiletRepository _repository;

  ReportNotifier(this._repository) : super(const ReportState());

  Future<void> submitReport({
    required int toiletSeq,
    required String toiletName,
    required String reportType,
    String? content,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      await _repository.submitReport(
        toiletSeq: toiletSeq,
        toiletName: toiletName,
        reportType: reportType,
        content: content,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      debugPrint('[ReportProvider] submitReport 오류: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final reportProvider =
    StateNotifierProvider.autoDispose<ReportNotifier, ReportState>(
  (ref) => ReportNotifier(ref.watch(toiletRepositoryProvider)),
);
