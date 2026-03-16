import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:daeddong/data/models/toilet_model.dart';

class ToiletRemoteDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<ToiletModel>> getToiletList({
    required double latitude,
    required double longitude,
    required double distance,
  }) async {
    if (latitude == 0 || longitude == 0 || distance <= 0) {
      throw Exception('유효하지 않은 위치 또는 거리 값입니다.');
    }

    debugPrint('[Supabase] get_nearby_toilets lat=$latitude, lng=$longitude, distance=$distance');

    final result = await _supabase.rpc('get_nearby_toilets', params: {
      'lat': latitude,
      'lng': longitude,
      'distance_meters': distance,
    });

    debugPrint('[Supabase] get_nearby_toilets length=${(result as List).length}');
    return result.map((e) => ToiletModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ToiletModel> getToiletDetail({required int seq}) async {
    debugPrint('[Supabase] getToiletDetail seq=$seq');

    final result = await _supabase
        .from('toilet')
        .select()
        .eq('seq', seq)
        .single();

    return ToiletModel.fromJson(result);
  }

  Future<void> submitReport({
    required int toiletSeq,
    required String toiletName,
    required String reportType,
    String? content,
  }) async {
    await _supabase.from('report').insert({
      'TOILET_SEQ': toiletSeq,
      'TOILET_NAME': toiletName,
      'REPORT_TYPE': reportType,
      'CONTENT': content,
    });
  }
}
