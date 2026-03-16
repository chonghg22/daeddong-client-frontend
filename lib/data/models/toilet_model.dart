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
      seq: json['seq'] as int?,
      name: json['name'] as String?,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      address: json['address'] as String?,
      si: json['si'] as String?,
      gungu: json['gungu'] as String?,
      openTime: json['openTime'] as String?,
      closeTime: json['closeTime'] as String?,
      toiletType: json['toiletType'] as String?,
      countMan: json['countMan'] as int?,
      countWomen: json['countWomen'] as int?,
      babyYn: json['babyYn'] as String?,
      unusualYn: json['unusualYn'] as String?,
      cctvYn: json['cctvYn'] as String?,
      alarmYn: json['alarmYn'] as String?,
      pwdYn: json['pwdYn'] as String?,
      openYn: json['openYn'] as String?,
      etc: json['etc'] as String?,
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
