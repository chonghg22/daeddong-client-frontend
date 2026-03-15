import 'package:daeddong/data/datasources/toilet_remote_datasource.dart';
import 'package:daeddong/data/models/toilet_model.dart';

class ToiletRepository {
  final ToiletRemoteDataSource _dataSource;

  ToiletRepository() : _dataSource = ToiletRemoteDataSource();

  Future<List<ToiletModel>> getToiletList({
    required double latitude,
    required double longitude,
    double? distance,
  }) {
    return _dataSource.getToiletList(
      latitude: latitude,
      longitude: longitude,
      distance: distance,
    );
  }
}
