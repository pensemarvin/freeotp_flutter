import 'package:hive/hive.dart';

part 'otp_account.g.dart';

@HiveType(typeId: 0)
class OTPAccount extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String issuer;
  
  @HiveField(2)
  final String name;
  
  @HiveField(3)
  final String secret;
  
  @HiveField(4, defaultValue: 6)
  final int digits;
  
  @HiveField(5, defaultValue: 30)
  final int period;
  
  @HiveField(6, defaultValue: OTPType.TOTP)
  final OTPType type;
  
  @HiveField(7, defaultValue: 'sha1')
  final String algorithm;
  
  @HiveField(8)
  final int addedDate;
  
  @HiveField(9, defaultValue: 0)
  int counter;
  
  OTPAccount({
    required this.id,
    required this.issuer,
    required this.name,
    required this.secret,
    this.digits = 6,
    this.period = 30,
    this.type = OTPType.TOTP,
    this.algorithm = 'sha1',
    int? addedDate,
    this.counter = 0,
  }) : addedDate = addedDate ?? DateTime.now().millisecondsSinceEpoch;
  
  String get label => name;
  
  String get accountLabel => issuer.isNotEmpty ? '$issuer ($name)' : name;
  
  // Convertir l'objet en Map pour la sérialisation JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issuer': issuer,
      'name': name,
      'secret': secret,
      'digits': digits,
      'period': period,
      'type': type.toString().split('.').last,
      'algorithm': algorithm,
      'addedDate': addedDate,
      'counter': counter,
    };
  }
  
  // Créer un OTPAccount à partir d'un Map (désérialisation JSON)
  factory OTPAccount.fromJson(Map<String, dynamic> json) {
    return OTPAccount(
      id: json['id'],
      issuer: json['issuer'] ?? '',
      name: json['name'],
      secret: json['secret'],
      digits: json['digits'] ?? 6,
      period: json['period'] ?? 30,
      type: OTPType.values.firstWhere(
        (e) => e.toString() == 'OTPType.${json['type']}',
        orElse: () => OTPType.TOTP,
      ),
      algorithm: json['algorithm'] ?? 'sha1',
      addedDate: json['addedDate'],
      counter: json['counter'] ?? 0,
    );
  }
  
  OTPAccount copyWith({
    String? id,
    String? issuer,
    String? name,
    String? secret,
    int? digits,
    int? period,
    OTPType? type,
    String? algorithm,
    int? counter,
  }) {
    return OTPAccount(
      id: id ?? this.id,
      issuer: issuer ?? this.issuer,
      name: name ?? this.name,
      secret: secret ?? this.secret,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      type: type ?? this.type,
      algorithm: algorithm ?? this.algorithm,
      addedDate: this.addedDate,
      counter: counter ?? this.counter,
    );
  }
}

@HiveType(typeId: 1)
enum OTPType {
  @HiveField(0)
  TOTP,
  
  @HiveField(1)
  HOTP,
}
