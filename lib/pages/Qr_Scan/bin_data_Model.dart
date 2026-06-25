class Vehicle {
  final int id;
  final String vehicleNumber;
  final String vehicleType;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
    };
  }
}

class BinData {
  final int? id;
  final String? project;
  final String? binNumber;
  final int? zone;
  final int? ward;
  String? location;
  String? pointName;
  double? latitude;
  double? longitude;

  BinData({
    this.id,
    this.project,
    this.binNumber,
    this.zone,
    this.ward,
    this.location,
    this.pointName,
    this.latitude,
    this.longitude,
  });

  factory BinData.fromJson(Map<String, dynamic> json) {
    return BinData(
      id: json['id'] ?? 0,
      project: json['project'] ?? '',
      binNumber: json['bin_number'] ?? '',
      zone: json['zone'] ?? 0,
      ward: json['ward'] ?? 0,
      location: json['location'] ?? '',
      pointName: json['point_name'] ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project': project,
      'bin_number': binNumber,
      'zone': zone,
      'ward': ward,
      'location': location,
      'point_name': pointName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool get isLocationMissing {
    return (location == null || location!.isEmpty) ||
        latitude == null ||
        longitude == null;
  }
}

class BinCollection {
  final int id;
  final bool? lockCard;
  final String binNumber;
  final String? zone;
  final String? ward;
  final String? collectedVehicleNumber;
  final String? deviceid;
  final String? beforeImage;
  final String? afterImage;
  final String? collectedOn;
  final String? latitude;
  final String? longitude;
  final int? bin;
  final int? collectedVehicle;
  final dynamic collectedBy;

  BinCollection({
    required this.id,
    this.lockCard,
    required this.binNumber,
    this.zone,
    this.ward,
    this.collectedVehicleNumber,
    this.deviceid,
    this.beforeImage,
    this.afterImage,
    this.collectedOn,
    this.latitude,
    this.longitude,
    this.bin,
    this.collectedVehicle,
    this.collectedBy,
  });

  factory BinCollection.fromJson(Map<String, dynamic> json) {
    return BinCollection(
      id: json['id'] ?? 0,
      lockCard: json['lock_card'] ?? false,
      binNumber: json['bin_number'] ?? '',
      zone: json['zone'] ?? '',
      ward: json['ward'],
      collectedVehicleNumber: json['collected_vehicle_number'] ?? '',
      deviceid: json['device_id'] ?? '',
      beforeImage: json['before'] ?? '',
      afterImage: json['after'] ?? '',
      collectedOn: json['collected_on'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
      bin: json['bin'],
      collectedVehicle: json['collected_vehicle'],
      collectedBy: json['collected_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lock_card': lockCard,
      'bin_number': binNumber,
      'zone': zone,
      'ward': ward,
      'collected_vehicle_number': collectedVehicleNumber,
      'device_id': deviceid,
      'before': beforeImage,
      'after': afterImage,
      'collected_on': collectedOn,
      'latitude': latitude,
      'longitude': longitude,
      'bin': bin,
      'collected_vehicle': collectedVehicle,
      'collected_by': collectedBy,
    };
  }
}