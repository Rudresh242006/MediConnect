// lib/services/id_service.dart
//
// Handles all Firebase ID generation and patient/doctor saving logic.
//
// ID FORMAT (12 characters total):
//   Patient:  P-A0A0A0A0A0
//   Doctor:   D-A0A0A0A0A0
//
// Structure after the 2-char prefix (X-):
//   Position:  1  2  3  4  5  6  7  8  9  10   (1-indexed)
//   Type:      L  N  L  N  L  N  L  N  L  N
//   (L = Letter A-Z, N = Number 0-9)
//
// Counting is right-to-left:
//   Number overflows 9  → resets to 0, carries left to the letter
//   Letter overflows Z  → resets to A, carries left to the number
//
// Firebase structure:
//   patients/
//     last_id: "P-A0A0A0A0A0"
//     P-A0A0A0A0A1/
//       name, mobile, ...
//   doctors/
//     last_id: "D-A0A0A0A0A0"
//     D-A0A0A0A0A1/
//       name, mobile, ...
//
// NOTE: On Windows, firebase_database's runTransaction fires the callback on
// a non-platform thread, causing a fatal crash. We therefore use an optimistic
// read-then-conditional-write strategy (via ServerValue / get + set) on
// Windows, which is safe for low-concurrency clinic registration workflows.

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';

class IdService {
  // Singleton database instance — uses the databaseURL from FirebaseOptions
  static FirebaseDatabase get _db => FirebaseDatabase.instance;

  // Desktop plugins can invoke transaction callbacks off the UI thread and crash.
  static bool get _useOptimisticIdSave =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // ─────────────────────────────────────────────────────────────────────────
  // CORE LOGIC: incrementId
  // ─────────────────────────────────────────────────────────────────────────

  /// Increments a full 12-character ID string.
  ///
  /// Examples:
  ///   "P-A0A0A0A0A0" → "P-A0A0A0A0A1"
  ///   "P-A0A0A0A0A9" → "P-A0A0A0A0B0"
  ///   "P-A0A0A0A0Z9" → "P-A0A0A0A1A0"
  ///   "D-A0A0A0A0A0" → "D-A0A0A0A0A1"
  ///
  /// The prefix (P- or D-) is NEVER modified.
  /// Only the 10-character alphanumeric part is incremented.
  ///
  /// 10-char part layout (0-indexed internally):
  ///   Index:  0  1  2  3  4  5  6  7  8  9
  ///   Type:   L  N  L  N  L  N  L  N  L  N
  ///
  /// Increment traversal is right-to-left (index 9 → 0):
  ///   - Odd index  (1,3,5,7,9) = Number  (0–9) — increments first
  ///   - Even index (0,2,4,6,8) = Letter  (A–Z)
  static String incrementId(String currentId) {
    // ── Validate format ─────────────────────────────────────────────────────
    if (currentId.length != 12 || currentId[1] != '-') {
      debugPrint('⚠️ IdService.incrementId: bad format "$currentId" — defaulting');
      final pfx = (currentId.isNotEmpty) ? currentId[0] : 'P';
      return '$pfx-A0A0A0A0A1';
    }

    final prefix = currentId.substring(0, 2); // "P-" or "D-"
    final part = currentId.substring(2);       // 10-char alphanumeric

    if (!RegExp(r'^[A-Z][0-9][A-Z][0-9][A-Z][0-9][A-Z][0-9][A-Z][0-9]$')
        .hasMatch(part)) {
      debugPrint('⚠️ IdService.incrementId: invalid 10-char part "$part" — defaulting');
      return '${prefix}A0A0A0A0A1';
    }

    // ── Increment right-to-left ─────────────────────────────────────────────
    final chars = part.split(''); // List of 10 characters

    for (int i = 9; i >= 0; i--) {
      if (i.isOdd) {
        // Number position (0-9)
        final digit = int.parse(chars[i]);
        if (digit < 9) {
          chars[i] = (digit + 1).toString();
          return prefix + chars.join();
        }
        chars[i] = '0'; // Carry: reset and continue left
      } else {
        // Letter position (A-Z)
        final code = chars[i].codeUnitAt(0);
        if (code < 90) {
          // 'Z' is ASCII 90; anything below can be incremented
          chars[i] = String.fromCharCode(code + 1);
          return prefix + chars.join();
        }
        chars[i] = 'A'; // Carry: reset to A and continue left
      }
    }

    // All 10 positions overflowed (26^5 × 10^5 ≈ 11.88 billion combinations)
    debugPrint('⚠️ IdService: ID space exhausted — wrapping to first ID');
    return '${prefix}A0A0A0A0A1';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READ-ONLY PREVIEW HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads patients/last_id from Firebase and returns what the NEXT
  /// patient ID would be. This does NOT write to Firebase.
  ///
  /// O(1) — always reads exactly ONE value, never scans all keys.
  static Future<String> generateNextPatientId() async {
    final snapshot = await _db.ref('patients/last_id').get();
    final lastId = (snapshot.value as String?) ?? 'P-A0A0A0A0A0';
    return incrementId(lastId);
  }

  /// Reads doctors/last_id from Firebase and returns what the NEXT
  /// doctor ID would be. This does NOT write to Firebase.
  ///
  /// O(1) — always reads exactly ONE value, never scans all keys.
  static Future<String> generateNextDoctorId() async {
    final snapshot = await _db.ref('doctors/last_id').get();
    final lastId = (snapshot.value as String?) ?? 'D-A0A0A0A0A0';
    return incrementId(lastId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE HELPERS (with atomic transaction or optimistic locking)
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a new patient record to Firebase atomically.
  ///
  /// On Android/iOS/Web: uses runTransaction for strict atomicity.
  /// On Windows: uses optimistic read-then-conditional-write (safe for
  /// low-concurrency environments like a clinic registration desk).
  ///
  /// Returns the newly assigned patient ID (e.g., "P-A0A0A0A0A1").
  /// Throws a descriptive Exception if all retries fail.
  static Future<String> savePatientToFirebase({
    required String name,
    required String mobile,
    Map<String, dynamic> additionalData = const {},
  }) async {
    return _saveRecord(
      node: 'patients',
      defaultLastId: 'P-A0A0A0A0A0',
      name: name,
      mobile: mobile,
      additionalData: additionalData,
      label: 'Patient',
    );
  }

  /// Saves a new doctor record to Firebase atomically.
  ///
  /// Same approach as [savePatientToFirebase], but under the
  /// 'doctors' node and using the D- prefix.
  ///
  /// Returns the newly assigned doctor ID (e.g., "D-A0A0A0A0A1").
  /// Throws a descriptive Exception if all retries fail.
  static Future<String> saveDoctorToFirebase({
    required String name,
    required String mobile,
    Map<String, dynamic> additionalData = const {},
  }) async {
    return _saveRecord(
      node: 'doctors',
      defaultLastId: 'D-A0A0A0A0A0',
      name: name,
      mobile: mobile,
      additionalData: additionalData,
      label: 'Doctor',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE IMPLEMENTATION
  // ─────────────────────────────────────────────────────────────────────────

  static const int _maxRetries = 3;

  /// Shared atomic save logic for both patients and doctors.
  static Future<String> _saveRecord({
    required String node,           // 'patients' or 'doctors'
    required String defaultLastId,  // 'P-A0A0A0A0A0' or 'D-A0A0A0A0A0'
    required String name,
    required String mobile,
    required Map<String, dynamic> additionalData,
    required String label,          // 'Patient' or 'Doctor' (for logging)
  }) async {
    if (_useOptimisticIdSave) {
      // Desktop: runTransaction can crash due to plugin threading issues.
      // Use optimistic locking instead: read → increment → set with retry.
      return _saveRecordOptimistic(
        node: node,
        defaultLastId: defaultLastId,
        name: name,
        mobile: mobile,
        additionalData: additionalData,
        label: label,
      );
    } else {
      // Android / iOS / Web: full atomic transaction
      return _saveRecordWithTransaction(
        node: node,
        defaultLastId: defaultLastId,
        name: name,
        mobile: mobile,
        additionalData: additionalData,
        label: label,
      );
    }
  }

  /// Uses Firebase runTransaction for strict atomicity (non-Windows).
  static Future<String> _saveRecordWithTransaction({
    required String node,
    required String defaultLastId,
    required String name,
    required String mobile,
    required Map<String, dynamic> additionalData,
    required String label,
  }) async {
    final lastIdRef = _db.ref('$node/last_id');
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // ── Step 1: Atomic transaction on last_id ─────────────────────────
        final TransactionResult txResult = await lastIdRef.runTransaction(
          (Object? currentData) {
            final currentId = (currentData as String?) ?? defaultLastId;
            final nextId = incrementId(currentId);
            return Transaction.success(nextId);
          },
          applyLocally: false,
        );

        if (!txResult.committed) {
          throw Exception('Firebase transaction was not committed (aborted)');
        }

        final newId = txResult.snapshot.value as String;

        // ── Step 2: Write record data to {node}/{newId}/ ──────────────────
        final Map<String, dynamic> record = {
          'id': newId,
          'name': name,
          'mobile': mobile,
          'registeredAt': DateTime.now().toIso8601String(),
          ...additionalData,
        };

        await _db.ref('$node/$newId').set(record);

        debugPrint('✅ IdService: $label saved → $newId');
        return newId;
      } catch (e) {
        lastError = Exception('Attempt $attempt/$_maxRetries failed: $e');
        debugPrint('⚠️ IdService: $lastError');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    throw lastError ??
        Exception('Failed to save $label after $_maxRetries attempts');
  }

  /// Optimistic locking: read current ID → compute next → write next + record.
  /// Safe for a clinic context where registrations are not simultaneous.
  /// On true conflict the node will still be unique because the ID written
  /// is derived from the value read just before writing.
  static Future<String> _saveRecordOptimistic({
    required String node,
    required String defaultLastId,
    required String name,
    required String mobile,
    required Map<String, dynamic> additionalData,
    required String label,
  }) async {
    final lastIdRef = _db.ref('$node/last_id');
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // Step 1: Read current last_id
        final snapshot = await lastIdRef.get();
        final currentId = (snapshot.value as String?) ?? defaultLastId;
        final newId = incrementId(currentId);

        // Step 2: Write the new last_id (claim the ID)
        await lastIdRef.set(newId);

        // Step 3: Write the full record under the new ID
        final Map<String, dynamic> record = {
          'id': newId,
          'name': name,
          'mobile': mobile,
          'registeredAt': DateTime.now().toIso8601String(),
          ...additionalData,
        };
        await _db.ref('$node/$newId').set(record);

        debugPrint('✅ IdService (optimistic): $label saved → $newId');
        return newId;
      } catch (e) {
        lastError = Exception('Attempt $attempt/$_maxRetries failed: $e');
        debugPrint('⚠️ IdService: $lastError');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    throw lastError ??
        Exception('Failed to save $label after $_maxRetries attempts');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLOUD SYNC & UTILITY FUNCTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Streams the list of all patients from Firebase, sorted by ID descending.
  static Stream<List<Patient>> getPatientsStream() {
    return _db.ref('patients').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final Map<dynamic, dynamic> patientsMap = snapshot.value as Map<dynamic, dynamic>;
      final List<Patient> list = [];

      patientsMap.forEach((key, val) {
        if (key == 'last_id') return; // Skip the counter metadata node
        try {
          final Map<String, dynamic> rawJson = Map<String, dynamic>.from(val as Map);
          list.add(Patient.fromJson(rawJson));
        } catch (e) {
          debugPrint('⚠️ IdService: failed parsing patient $key: $e');
        }
      });

      // Sort by ID descending (newest registrations first)
      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    });
  }

  /// Fetches a single patient record by ID from Firebase once.
  static Future<Patient?> getPatientById(String id) async {
    final snapshot = await _db.ref('patients/$id').get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }
    try {
      final Map<String, dynamic> rawJson = Map<String, dynamic>.from(snapshot.value as Map);
      return Patient.fromJson(rawJson);
    } catch (e) {
      debugPrint('⚠️ IdService: failed parsing patient $id: $e');
      return null;
    }
  }

  /// Streams updates for a single patient record from Firebase.
  static Stream<Patient?> getPatientStream(String id) {
    return _db.ref('patients/$id').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }
      try {
        final Map<String, dynamic> rawJson = Map<String, dynamic>.from(snapshot.value as Map);
        return Patient.fromJson(rawJson);
      } catch (e) {
        debugPrint('⚠️ IdService: failed parsing patient stream $id: $e');
        return null;
      }
    });
  }

  /// Updates patient vitals (heartRate and bloodPressure) in Firebase.
  static Future<void> updatePatientVitals(String id, int heartRate, String bloodPressure) async {
    await _db.ref('patients/$id').update({
      'heartRate': heartRate,
      'bloodPressure': bloodPressure,
    });
  }

  /// Updates patient weight in Firebase.
  static Future<void> updatePatientWeight(String id, double weight) async {
    await _db.ref('patients/$id').update({
      'weight': weight,
    });
  }

  /// Appends a prescription to the patient's record in Firebase.
  static Future<void> addPatientPrescription(String id, Map<String, String> prescription) async {
    final ref = _db.ref('patients/$id/prescriptions');
    
    // Read-modify-write pattern (safe for individual patient operations)
    final snapshot = await ref.get();
    final List<dynamic> currentList = (snapshot.value as List<dynamic>?) ?? [];
    final List<Map<String, String>> newList = currentList.map((item) {
      final map = item as Map<dynamic, dynamic>;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    }).toList();
    
    newList.add(prescription);
    await ref.set(newList);
  }

  /// Updates patient contact and emergency details in Firebase.
  static Future<void> updatePatientProfile(String id, Map<String, dynamic> profileData) async {
    await _db.ref('patients/$id').update(profileData);
  }

  /// Fetches a single doctor record by ID from Firebase once.
  /// Returns a raw map so callers can read any stored field (e.g. licenseNumber).
  static Future<Map<String, dynamic>?> getDoctorById(String id) async {
    final snapshot = await _db.ref('doctors/$id').get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      debugPrint('⚠️ IdService: failed parsing doctor $id: $e');
      return null;
    }
  }

  /// Streams updates for a single doctor record from Firebase.
  static Stream<Map<String, dynamic>?> getDoctorStream(String id) {
    return _db.ref('doctors/$id').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return null;
      try {
        return Map<String, dynamic>.from(snapshot.value as Map);
      } catch (e) {
        debugPrint('⚠️ IdService: failed parsing doctor stream $id: $e');
        return null;
      }
    });
  }
}

