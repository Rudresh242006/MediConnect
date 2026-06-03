class Patient {
  final String id;
  final String fullName;
  final DateTime dateOfBirth;
  final double weight;
  final double height; // in cm
  final String bloodGroup;
  final DateTime registrationDate;
  final String gender;
  final String bloodPressure;
  final int heartRate;

  // Contact Information
  final String phoneNumber;
  final String email;
  final String address;

  // Emergency Contact
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContactRelation;

  // Clinical Safety
  final List<String> allergies;
  final List<String> medicalConditions;

  // Prescriptions
  final List<Map<String, String>> prescriptions;

  Patient({
    required this.id,
    required this.fullName,
    required this.dateOfBirth,
    required this.weight,
    this.height = 170.0,
    required this.bloodGroup,
    required this.registrationDate,
    required this.gender,
    this.bloodPressure = '120/80',
    this.heartRate = 72,
    this.phoneNumber = '',
    this.email = '',
    this.address = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.emergencyContactRelation = '',
    this.allergies = const [],
    this.medicalConditions = const [],
    this.prescriptions = const [],
  });

  /// Computed age from date of birth
  int get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    return years;
  }

  /// Computed BMI from height (cm) and weight (kg)
  double get bmi {
    if (height <= 0) return 0;
    final heightM = height / 100.0;
    return weight / (heightM * heightM);
  }

  /// BMI Classification
  String get bmiCategory {
    final b = bmi;
    if (b <= 0) return 'Unknown';
    if (b < 16.0) return 'Severe Underweight';
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal';
    if (b < 30.0) return 'Overweight';
    if (b < 35.0) return 'Obese Class I';
    if (b < 40.0) return 'Obese Class II';
    return 'Obese Class III';
  }

  /// Returns a copy of this patient with updated fields.
  Patient copyWith({
    String? id,
    String? fullName,
    DateTime? dateOfBirth,
    double? weight,
    double? height,
    String? bloodGroup,
    DateTime? registrationDate,
    String? gender,
    String? bloodPressure,
    int? heartRate,
    String? phoneNumber,
    String? email,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    List<String>? allergies,
    List<String>? medicalConditions,
    List<Map<String, String>>? prescriptions,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      registrationDate: registrationDate ?? this.registrationDate,
      gender: gender ?? this.gender,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      prescriptions: prescriptions ?? this.prescriptions,
    );
  }

  // Convert a Patient object into a Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'weight': weight,
      'height': height,
      'bloodGroup': bloodGroup,
      'registrationDate': registrationDate.toIso8601String(),
      'gender': gender,
      'bloodPressure': bloodPressure,
      'heartRate': heartRate,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'prescriptions': prescriptions,
    };
  }

  // Create a Patient object from a Map (JSON) — backward-compatible and robust
  factory Patient.fromJson(Map<String, dynamic> json) {
    // Safely decode prescriptions list
    List<Map<String, String>> parsedPrescriptions = [];
    if (json['prescriptions'] != null) {
      try {
        final rawList = json['prescriptions'] as List<dynamic>;
        parsedPrescriptions = rawList.map((item) {
          final map = item as Map<dynamic, dynamic>;
          return map.map((k, v) => MapEntry(k.toString(), v.toString()));
        }).toList();
      } catch (_) {
        parsedPrescriptions = [];
      }
    }

    // Safely decode string lists
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      try {
        return (raw as List<dynamic>).map((e) => e.toString()).toList();
      } catch (_) {
        return [];
      }
    }

    // Backward-compatible DOB handling:
    // If 'dateOfBirth' exists, use it. Otherwise estimate from 'age' field.
    DateTime dob;
    if (json['dateOfBirth'] != null) {
      dob = DateTime.parse(json['dateOfBirth'] as String);
    } else if (json['age'] != null) {
      final age = json['age'] as int;
      final now = DateTime.now();
      dob = DateTime(now.year - age, now.month, now.day);
    } else {
      dob = DateTime(2000, 1, 1);
    }

    // Safely parse registration date supporting both 'registrationDate' and 'registeredAt'
    DateTime regDate = DateTime.now();
    final regDateStr = json['registrationDate'] ?? json['registeredAt'];
    if (regDateStr != null) {
      try {
        regDate = DateTime.parse(regDateStr.toString());
      } catch (_) {
        // Fallback to current time
      }
    }

    final idVal = (json['id'] as String?) ?? 'Unknown';
    final fullNameVal = (json['fullName'] as String?) ?? (json['name'] as String?) ?? 'Patient';

    return Patient(
      id: idVal,
      fullName: fullNameVal,
      dateOfBirth: dob,
      weight: (json['weight'] as num?)?.toDouble() ?? 70.0,
      height: (json['height'] as num?)?.toDouble() ?? 170.0,
      bloodGroup: (json['bloodGroup'] as String?) ?? 'O+',
      registrationDate: regDate,
      gender: (json['gender'] as String?) ?? 'Not Specified',
      bloodPressure: (json['bloodPressure'] as String?) ?? '120/80',
      heartRate: (json['heartRate'] as int?) ?? 72,
      phoneNumber: (json['phoneNumber'] as String?) ?? (json['mobile'] != null ? json['mobile'].toString() : ''),
      email: (json['email'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      emergencyContactName: (json['emergencyContactName'] as String?) ?? '',
      emergencyContactPhone: (json['emergencyContactPhone'] as String?) ?? '',
      emergencyContactRelation: (json['emergencyContactRelation'] as String?) ?? '',
      allergies: parseStringList(json['allergies']),
      medicalConditions: parseStringList(json['medicalConditions']),
      prescriptions: parsedPrescriptions,
    );
  }
}
