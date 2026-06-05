import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient.dart';

enum SessionKind { none, doctor, patient }

class SessionInfo {
  final SessionKind kind;
  final Patient? patient;

  const SessionInfo(this.kind, {this.patient});
}

/// Persists and restores logged-in patient/doctor sessions via SharedPreferences.
class SessionService {
  static Future<SessionInfo> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();

    final doctorId = prefs.getString('logged_in_doctor_id');
    if (doctorId != null && doctorId.isNotEmpty) {
      return const SessionInfo(SessionKind.doctor);
    }

    final activePatientId = prefs.getString('active_patient_id');
    if (activePatientId != null && activePatientId.isNotEmpty) {
      final patient = _patientFromPrefs(prefs, activePatientId);
      if (patient != null) {
        return SessionInfo(SessionKind.patient, patient: patient);
      }
    }

    return const SessionInfo(SessionKind.none);
  }

  static Patient? _patientFromPrefs(
    SharedPreferences prefs,
    String patientId,
  ) {
    final patientsJson = prefs.getStringList('registered_patients') ?? [];
    for (final pj in patientsJson) {
      try {
        final pMap = jsonDecode(pj) as Map<String, dynamic>;
        if (pMap['id'] == patientId) {
          return Patient.fromJson(pMap);
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearPatientSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_patient_id');
  }

  static Future<void> clearDoctorSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_doctor_id');
    await prefs.remove('logged_in_doctor_name');
    await prefs.remove('logged_in_doctor_license');
  }
}
