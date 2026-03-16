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
      seq: int.tryParse((json['seq'] ?? json['SEQ'])?.toString() ?? ''),
      name: (json['name'] ?? json['NAME'])?.toString(),
      latitude: double.tryParse((json['latitude'] ?? json['LATITUDE'])?.toString() ?? ''),
      longitude: double.tryParse((json['longitude'] ?? json['LONGITUDE'])?.toString() ?? ''),
      address: (json['address'] ?? json['ADDRESS'])?.toString(),
      si: (json['si'] ?? json['SI'])?.toString(),
      gungu: (json['gungu'] ?? json['GUNGU'])?.toString(),
      openTime: (json['openTime'] ?? json['OPEN_TIME'])?.toString(),
      closeTime: (json['closeTime'] ?? json['CLOSE_TIME'])?.toString(),
      toiletType: (json['toiletType'] ?? json['TOILET_TYPE'])?.toString(),
      countMan: int.tryParse((json['countMan'] ?? json['COUNT_MAN'])?.toString() ?? ''),
      countWomen: int.tryParse((json['countWomen'] ?? json['COUNT_WOMEN'])?.toString() ?? ''),
      babyYn: (json['babyYn'] ?? json['BABY_YN'])?.toString(),
      unusualYn: (json['unusualYn'] ?? json['UNUSUAL_YN'])?.toString(),
      cctvYn: (json['cctvYn'] ?? json['CCTV_YN'])?.toString(),
      alarmYn: (json['alarmYn'] ?? json['ALARM_YN'])?.toString(),
      pwdYn: (json['pwdYn'] ?? json['PWD_YN'])?.toString(),
      openYn: (json['openYn'] ?? json['OPEN_YN'])?.toString(),
      etc: (json['etc'] ?? json['ETC'])?.toString(),
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
