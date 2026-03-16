class ToiletModel {
  final int? seq;
  final String? name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? si;
  final String? gungu;
  final String? openTime;
  final String? closeTime;
  final String? toiletType;
  final int? countMan;
  final int? countWomen;
  final String? babyYn;
  final String? unusualYn;
  final String? cctvYn;
  final String? alarmYn;
  final String? pwdYn;
  final String? openYn;
  final String? etc;

  const ToiletModel({
    this.seq,
    this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.si,
    this.gungu,
    this.openTime,
    this.closeTime,
    this.toiletType,
    this.countMan,
    this.countWomen,
    this.babyYn,
    this.unusualYn,
    this.cctvYn,
    this.alarmYn,
    this.pwdYn,
    this.openYn,
    this.etc,
  });

  factory ToiletModel.fromJson(Map<String, dynamic> json) {
    return ToiletModel(
      seq: int.tryParse(json['seq']?.toString() ?? ''),
      name: json['name']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      address: json['address']?.toString(),
      si: json['si']?.toString(),
      gungu: json['gungu']?.toString(),
      openTime: json['openTime']?.toString(),
      closeTime: json['closeTime']?.toString(),
      toiletType: json['toiletType']?.toString(),
      countMan: int.tryParse(json['countMan']?.toString() ?? ''),
      countWomen: int.tryParse(json['countWomen']?.toString() ?? ''),
      babyYn: json['babyYn']?.toString(),
      unusualYn: json['unusualYn']?.toString(),
      cctvYn: json['cctvYn']?.toString(),
      alarmYn: json['alarmYn']?.toString(),
      pwdYn: json['pwdYn']?.toString(),
      openYn: json['openYn']?.toString(),
      etc: json['etc']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'si': si,
        'gungu': gungu,
        'openTime': openTime,
        'closeTime': closeTime,
        'toiletType': toiletType,
        'countMan': countMan,
        'countWomen': countWomen,
        'babyYn': babyYn,
        'unusualYn': unusualYn,
        'cctvYn': cctvYn,
        'alarmYn': alarmYn,
        'pwdYn': pwdYn,
        'openYn': openYn,
        'etc': etc,
      };
}
