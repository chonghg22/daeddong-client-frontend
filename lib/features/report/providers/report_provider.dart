import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daeddong/core/constants/app_constants.dart';

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
  final Dio _dio;

  ReportNotifier()
      : _dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl)),
        super(const ReportState());

  Future<void> submitReport({
    required int toiletSeq,
    required String toiletName,
    required String reportType,
    String? content,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final response = await _dio.post(
        '/report/insertReport',
        data: {
          'toiletSeq': toiletSeq,
          'toiletName': toiletName,
          'reportType': reportType,
          if (content != null && content.isNotEmpty) 'content': content,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['resultCode'] != '0000') {
        throw Exception('API 오류: ${data['resultCode']}');
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final reportProvider =
    StateNotifierProvider.autoDispose<ReportNotifier, ReportState>(
  (ref) => ReportNotifier(),
);
