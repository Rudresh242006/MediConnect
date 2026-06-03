import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/patient.dart';
import '../services/id_service.dart';
import '../main.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  // ── Patient data ─────────────────────────────────────────────────────────
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  bool _hasSearched = false; // True once user types ≥1 character
  StreamSubscription<List<Patient>>? _patientsSubscription;

  // ── Search ───────────────────────────────────────────────────────────────
  final _searchController = TextEditingController();

  // ── Doctor session ───────────────────────────────────────────────────────
  String _doctorName = 'Doctor';
  String _doctorId = '';
  String _doctorLicense = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorSession();
    _subscribeToPatients();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── Session load ──────────────────────────────────────────────────────────

  Future<void> _loadDoctorSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _doctorName = prefs.getString('logged_in_doctor_name') ?? 'Doctor';
        _doctorId = prefs.getString('logged_in_doctor_id') ?? '';
        _doctorLicense = prefs.getString('logged_in_doctor_license') ?? '';
      });
    }
  }

  // ── Firebase stream ───────────────────────────────────────────────────────

  void _subscribeToPatients() {
    _patientsSubscription = IdService.getPatientsStream().listen(
      (patients) {
        if (!mounted) return;
        setState(() {
          _allPatients = patients;
          _isLoading = false;
          if (_hasSearched) _applyFilter();
        });
      },
      onError: (error) {
        debugPrint('Error loading patients from Firebase: $error');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  // ── Search / filter ───────────────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _hasSearched = query.isNotEmpty;
      if (_hasSearched) {
        _applyFilter();
      } else {
        _filteredPatients = [];
      }
    });
  }

  void _applyFilter() {
    final rawQuery = _searchController.text.trim().toLowerCase();
    final cleanQuery = rawQuery.replaceAll(RegExp(r'[^a-z0-9]'), '');
    _filteredPatients = _allPatients.where((p) {
      final cleanId = p.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return p.fullName.toLowerCase().contains(rawQuery) ||
          cleanId.contains(cleanQuery);
    }).toList();
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Logout?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        content: Text(
          'Are you sure you want to log out of the Doctor Portal?',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_in_doctor_id');
      await prefs.remove('logged_in_doctor_name');
      await prefs.remove('logged_in_doctor_license');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  // ── Vital classifiers ─────────────────────────────────────────────────────

  static Map<String, dynamic> classifyBP(String bp) {
    try {
      final parts = bp.split('/');
      if (parts.length != 2) return {'label': 'Unknown', 'color': Colors.grey};
      final sys = int.parse(parts[0].trim());
      final dia = int.parse(parts[1].trim());
      if (sys > 180 || dia > 120) return {'label': 'Crisis', 'color': const Color(0xFFDC2626)};
      if (sys >= 140 || dia >= 90) return {'label': 'Hyp. Stage 2', 'color': const Color(0xFFEA580C)};
      if (sys >= 130 || dia >= 80) return {'label': 'Hyp. Stage 1', 'color': const Color(0xFFF59E0B)};
      if (sys >= 120 && dia < 80) return {'label': 'Elevated', 'color': const Color(0xFFF59E0B)};
      return {'label': 'Normal', 'color': const Color(0xFF10B981)};
    } catch (_) {
      return {'label': 'Unknown', 'color': Colors.grey};
    }
  }

  static Map<String, dynamic> classifyHR(int hr) {
    if (hr < 60) return {'label': 'Bradycardia', 'color': const Color(0xFFF59E0B)};
    if (hr > 100) return {'label': 'Tachycardia', 'color': const Color(0xFFEA580C)};
    return {'label': 'Normal', 'color': const Color(0xFF10B981)};
  }

  bool _isCritical(Patient p) {
    final bpClass = classifyBP(p.bloodPressure);
    final hrClass = classifyHR(p.heartRate);
    return ['Crisis', 'Hyp. Stage 2'].contains(bpClass['label']) ||
        hrClass['label'] == 'Tachycardia';
  }

  // ── Prescription dialog ───────────────────────────────────────────────────

  void _showPrescriptionDialog(BuildContext context, Patient patient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final instrCtrl = TextEditingController();
    final daysCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D9488).withOpacity(0.1)
                          : const Color(0xFF0D9488).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: Color(0xFF0D9488), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Write Prescription',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B))),
                        Text('For: ${patient.fullName}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _dlgField(ctx, isDark, medCtrl, 'Medication Name',
                  'e.g. Amoxicillin 500mg'),
              const SizedBox(height: 12),
              _dlgField(ctx, isDark, dosageCtrl, 'Dosage',
                  'e.g. 1 Capsule – 3× Daily'),
              const SizedBox(height: 12),
              _dlgField(ctx, isDark, instrCtrl, 'Instructions',
                  'e.g. Take with food'),
              const SizedBox(height: 12),
              _dlgField(ctx, isDark, daysCtrl, 'Duration (days)', 'e.g. 7',
                  inputType: TextInputType.number),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (medCtrl.text.trim().isEmpty) return;
                        final days = daysCtrl.text.trim();
                        final rx = {
                          'medication': medCtrl.text.trim(),
                          'dosage': dosageCtrl.text.trim(),
                          'instruction': instrCtrl.text.trim(),
                          'timeLeft': days.isNotEmpty
                              ? '$days days left'
                              : 'Ongoing',
                        };
                        try {
                          await IdService.addPatientPrescription(
                              patient.id, rx);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Prescription added successfully!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error saving prescription: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Update vitals dialog ──────────────────────────────────────────────────

  void _showUpdateVitalsDialog(BuildContext context, Patient patient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hrCtrl =
        TextEditingController(text: patient.heartRate.toString());
    final bpCtrl =
        TextEditingController(text: patient.bloodPressure);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_heart_rounded,
                      color: isDark
                          ? const Color(0xFFF43F5E)
                          : const Color(0xFFF43F5E),
                      size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Vitals',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B))),
                        Text('For: ${patient.fullName}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _dlgField(ctx, isDark, hrCtrl, 'Heart Rate (bpm)', '60–100',
                  inputType: TextInputType.number),
              const SizedBox(height: 12),
              _dlgField(
                  ctx, isDark, bpCtrl, 'Blood Pressure', 'e.g. 120/80'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final hr = int.tryParse(hrCtrl.text.trim());
                        final bp = bpCtrl.text.trim();
                        if (hr == null || hr < 20 || hr > 300) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Invalid heart rate')),
                          );
                          return;
                        }
                        if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(bp)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Use format Systolic/Diastolic')),
                          );
                          return;
                        }
                        try {
                          await IdService.updatePatientVitals(
                              patient.id, hr, bp);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Vitals updated successfully!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error updating vitals: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Update',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dlgField(BuildContext ctx, bool isDark,
      TextEditingController ctrl, String label, String hint,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            fontSize: 13),
        hintStyle: TextStyle(
            color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
            fontSize: 13),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF0D9488),
              width: 1.8),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor:
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF0D4D47),
                            const Color(0xFF0F172A)
                          ]
                        : [
                            const Color(0xFF0D9488),
                            const Color(0xFF134E4A)
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: back + theme toggle + logout
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => _logout(context),
                          tooltip: 'Logout',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () =>
                              MediConnectApp.of(context)?.toggleTheme(),
                        ),
                        const SizedBox(width: 4),
                        _logoutButton(context, isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Doctor info row
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.medical_services_rounded,
                                color: Colors.white,
                                size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. $_doctorName',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_doctorId.isNotEmpty)
                                  Text(
                                    '$_doctorId  ·  $_doctorLicense',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withOpacity(0.7),
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_allPatients.length} patient${_allPatients.length == 1 ? '' : 's'} in system',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.6),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search bar pinned at bottom of sliver
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: isDark
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF0D9488),
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by patient ID or name...',
                          hintStyle: TextStyle(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : Colors.grey.shade400,
                              fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(Icons.close_rounded,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade400,
                            size: 18),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? _buildLoadingState()
            : !_hasSearched
                ? _buildPromptState(isDark)
                : _filteredPatients.isEmpty
                    ? _buildNoResultsState(isDark)
                    : _buildPatientList(isDark),
      ),
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF0D9488)),
    );
  }

  Widget _buildPromptState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D9488).withOpacity(0.08)
                    : const Color(0xFF0D9488).withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.manage_search_rounded,
                size: 64,
                color: const Color(0xFF0D9488).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search for a Patient',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Type a patient ID (e.g. P-A0A0A0A0A1) or name in the search bar above to view their records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),
            // Quick stat chips
            if (_allPatients.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip(isDark, '${_allPatients.length}',
                      'Total Patients', Icons.people_rounded),
                  const SizedBox(width: 12),
                  _statChip(
                    isDark,
                    '${_allPatients.where(_isCritical).length}',
                    'Critical',
                    Icons.priority_high_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ],
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _statChip(bool isDark, String value, String label, IconData icon,
      {Color color = const Color(0xFF0D9488)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 64,
              color: isDark
                  ? const Color(0xFF475569)
                  : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No matching patients found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different ID or name',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF64748B)
                    : Colors.grey.shade400),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPatientList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = _filteredPatients[index];
        return _buildPatientCard(context, isDark, patient, index);
      },
    );
  }

  // ── Patient card ──────────────────────────────────────────────────────────

  Widget _buildPatientCard(
      BuildContext context, bool isDark, Patient patient, int index) {
    final bpClass = classifyBP(patient.bloodPressure);
    final hrClass = classifyHR(patient.heartRate);
    final isCrit = _isCritical(patient);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCrit
              ? const Color(0xFFDC2626).withOpacity(0.4)
              : (isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFF1F5F9)),
          width: isCrit ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCrit
                ? const Color(0xFFDC2626).withOpacity(0.08)
                : Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isDark
                          ? const Color(0xFF0D9488).withOpacity(0.15)
                          : const Color(0xFF0D9488).withOpacity(0.1),
                      child: Text(
                        patient.fullName.isNotEmpty
                            ? patient.fullName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    if (isCrit)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.priority_high_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${patient.id}  ·  ${patient.gender}  ·  ${patient.age} yrs  ·  ${patient.bloodGroup}',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Vital chips ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _vitalChip(isDark, '❤ ${patient.heartRate} bpm',
                    hrClass['label'] as String,
                    hrClass['color'] as Color),
                const SizedBox(width: 8),
                _vitalChip(isDark, '⚡ ${patient.bloodPressure}',
                    bpClass['label'] as String,
                    bpClass['color'] as Color),
                const Spacer(),
                // Allergy badge
                if (patient.allergies.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFF59E0B)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.allergies.length} allergy',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _actionBtn(
                  isDark: isDark,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  color: const Color(0xFF0D9488),
                  onTap: () => Navigator.pushNamed(context, '/dashboard',
                      arguments: patient),
                ),
                _actionBtn(
                  isDark: isDark,
                  icon: Icons.medication_rounded,
                  label: 'Prescribe',
                  color: const Color(0xFF4F46E5),
                  onTap: () =>
                      _showPrescriptionDialog(context, patient),
                ),
                _actionBtn(
                  isDark: isDark,
                  icon: Icons.monitor_heart_rounded,
                  label: 'Vitals',
                  color: const Color(0xFFF43F5E),
                  onTap: () =>
                      _showUpdateVitalsDialog(context, patient),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms, duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  // ── Small reusable widgets ────────────────────────────────────────────────

  Widget _logoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _logout(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.logout_rounded, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('Logout',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _vitalChip(bool isDark, String text, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
