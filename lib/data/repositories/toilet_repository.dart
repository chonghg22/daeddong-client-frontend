import 'package:daeddong/data/datasources/toilet_remote_datasource.dart';
import 'package:daeddong/data/models/toilet_model.dart';

class ToiletRepository {
  final ToiletRemoteDataSource _dataSource;

  ToiletRepository() : _dataSource = ToiletRemoteDataSource();

  Future<List<ToiletModel>> getToiletList({
    required double latitude,
    required double longitude,
    required double distance,
  }) {
    return _dataSource.getToiletList(
      latitude: latitude,
      longitude: longitude,
      distance: distance,
    );
  }

  Future<ToiletModel> getToiletDetail({required int seq}) {
    return _dataSource.getToiletDetail(seq: seq);
  }

  Future<void> submitReport({
    required int toiletSeq,
    required String toiletName,
    required String reportType,
    String? content,
  }) {
    return _dataSource.submitReport(
      toiletSeq: toiletSeq,
      toiletName: toiletName,
      reportType: reportType,
      content: content,
    );
  }
}
