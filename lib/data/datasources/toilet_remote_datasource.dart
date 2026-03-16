import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:daeddong/core/constants/app_constants.dart';
import 'package:daeddong/data/models/toilet_model.dart';

class ToiletRemoteDataSource {
  final Dio _dio;

  ToiletRemoteDataSource() : _dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));

  Future<List<ToiletModel>> getToiletList({
    required double latitude,
    required double longitude,
    required double distance,
  }) async {
    if (latitude == 0 || longitude == 0 || distance <= 0) {
      throw Exception('유효하지 않은 위치 또는 거리 값입니다.');
    }

    debugPrint('BASE_URL: ${AppConstants.baseUrl}');
    debugPrint('[API] getToiletList lat=$latitude, lng=$longitude, distance=$distance');

    final response = await _dio.get(
      '/toiletList',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'distance': distance,
      },
    );

    final data = response.data as Map<String, dynamic>;
    debugPrint('[API] response resultCode=${data['resultCode']}, toiletList length=${(data['toiletList'] as List?)?.length}');

    if (data['resultCode'] != '0000') {
      throw Exception('API 오류: ${data['resultCode']}');
    }

    try {
      final list = data['toiletList'] as List<dynamic>;
      return list.map((e) => ToiletModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[API] 파싱 오류: $e');
      debugPrint('[API] raw data: ${data['toiletList']?.toString().substring(0, 200)}');
      rethrow;
    }
  }

  Future<ToiletModel> getToiletDetail({required int seq}) async {
    final response = await _dio.get(
      '/toiletDetail',
      queryParameters: {'seq': seq},
    );

    final data = response.data as Map<String, dynamic>;
    if (data['resultCode'] != '0000') {
      throw Exception('API 오류: ${data['resultCode']}');
    }

    return ToiletModel.fromJson(data['toiletInfo'] as Map<String, dynamic>);
  }
}
