import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../services/id_service.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Patient? _patient;
  bool _isLoading = true;

  bool _isEditingHR = false;
  bool _isEditingBP = false;
  bool _isEditingW = false;

  late TextEditingController _hrEditController;
  late TextEditingController _bpEditController;
  late TextEditingController _wEditController;
  
  StreamSubscription<Patient?>? _patientSubscription;
  bool _didInitSubscription = false;

  @override
  void initState() {
    super.initState();
    _hrEditController = TextEditingController();
    _bpEditController = TextEditingController();
    _wEditController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitSubscription) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? targetId;
      if (args is Patient) {
        targetId = args.id;
      }
      _subscribeToPatient(targetId);
      _didInitSubscription = true;
    }
  }

  @override
  void dispose() {
    _patientSubscription?.cancel();
    _hrEditController.dispose();
    _bpEditController.dispose();
    _wEditController.dispose();
    super.dispose();
  }

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
          'Are you sure you want to log out of the Patient Portal?',
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
      await prefs.remove('active_patient_id');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  void _subscribeToPatient(String? targetId) async {
    if (targetId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final patientsJson = prefs.getStringList('registered_patients') ?? [];
        if (patientsJson.isNotEmpty) {
          final lastMap = jsonDecode(patientsJson.last) as Map<String, dynamic>;
          targetId = lastMap['id'] as String?;
        }
      } catch (e) {
        debugPrint('Error getting fallback patient ID: $e');
      }
    }

    if (targetId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _patientSubscription = IdService.getPatientStream(targetId).listen(
      (patient) {
        if (!mounted) return;
        setState(() {
          _patient = patient;
          _isLoading = false;
        });
      },
      onError: (err) {
        debugPrint('Error listening to patient updates: $err');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _saveVitalField(int index, String value) async {
    if (_patient == null) return;
    try {
      if (index == 0) {
        final hr = int.tryParse(value);
        if (hr == null || hr < 20 || hr > 300) {
          _showErrorSnackBar('Invalid heart rate value (20-300)');
          return;
        }
        await IdService.updatePatientVitals(_patient!.id, hr, _patient!.bloodPressure);
      } else if (index == 1) {
        if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(value)) {
          _showErrorSnackBar('Invalid BP format. Use Systolic/Diastolic (e.g. 120/80)');
          return;
        }
        await IdService.updatePatientVitals(_patient!.id, _patient!.heartRate, value);
      } else {
        final w = double.tryParse(value);
        if (w == null || w < 2.0 || w > 500.0) {
          _showErrorSnackBar('Invalid weight value (2-500)');
          return;
        }
        await IdService.updatePatientWeight(_patient!.id, w);
      }

      setState(() {
        if (index == 0) _isEditingHR = false;
        if (index == 1) _isEditingBP = false;
        if (index == 2) _isEditingW = false;
      });
      _showSuccessSnackBar('Vital updated successfully!');
    } catch (e) {
      debugPrint('Error saving updated vitals: $e');
      _showErrorSnackBar('Failed to update vitals.');
    }
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isDark ? const Color(0xFF14B8A6) : Colors.teal.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// AHA Blood Pressure Classification
  Map<String, dynamic> _classifyBP(String bp) {
    try {
      final parts = bp.split('/');
      if (parts.length != 2) return {'label': 'Unknown', 'color': Colors.grey, 'icon': Icons.help_outline_rounded};
      final sys = int.parse(parts[0].trim());
      final dia = int.parse(parts[1].trim());

      if (sys > 180 || dia > 120) {
        return {'label': 'Hypertensive Crisis', 'color': const Color(0xFFDC2626), 'icon': Icons.emergency_rounded};
      } else if (sys >= 140 || dia >= 90) {
        return {'label': 'Hypertension Stage 2', 'color': const Color(0xFFEA580C), 'icon': Icons.warning_rounded};
      } else if (sys >= 130 || dia >= 80) {
        return {'label': 'Hypertension Stage 1', 'color': const Color(0xFFF59E0B), 'icon': Icons.warning_amber_rounded};
      } else if (sys >= 120 && dia < 80) {
        return {'label': 'Elevated', 'color': const Color(0xFFF59E0B), 'icon': Icons.trending_up_rounded};
      } else {
        return {'label': 'Optimal', 'color': const Color(0xFF10B981), 'icon': Icons.check_circle_rounded};
      }
    } catch (_) {
      return {'label': 'Unknown', 'color': Colors.grey, 'icon': Icons.help_outline_rounded};
    }
  }

  /// Heart Rate Classification
  Map<String, dynamic> _classifyHR(int hr) {
    if (hr < 40) return {'label': 'Severe Bradycardia', 'color': const Color(0xFFDC2626), 'icon': Icons.emergency_rounded};
    if (hr < 60) return {'label': 'Bradycardia', 'color': const Color(0xFFF59E0B), 'icon': Icons.warning_amber_rounded};
    if (hr > 150) return {'label': 'Severe Tachycardia', 'color': const Color(0xFFDC2626), 'icon': Icons.emergency_rounded};
    if (hr > 100) return {'label': 'Tachycardia', 'color': const Color(0xFFEA580C), 'icon': Icons.warning_rounded};
    return {'label': 'Normal', 'color': const Color(0xFF10B981), 'icon': Icons.check_circle_rounded};
  }

  /// Weight classification based on real BMI
  Map<String, dynamic> _classifyWeight(double weightKg, double bmi) {
    if (bmi <= 0) return {'label': 'Stable', 'color': const Color(0xFF10B981)};
    if (bmi < 18.5) return {'label': 'Underweight', 'color': const Color(0xFFF59E0B)};
    if (bmi < 25.0) return {'label': 'Normal Weight', 'color': const Color(0xFF10B981)};
    if (bmi < 30.0) return {'label': 'Overweight', 'color': const Color(0xFFEA580C)};
    return {'label': 'Obese', 'color': const Color(0xFFDC2626)};
  }

  /// BMI classification
  Map<String, dynamic> _classifyBMI(double bmi, String category) {
    Color color;
    if (bmi <= 0) {
      color = Colors.grey;
    } else if (bmi < 18.5) {
      color = const Color(0xFFF59E0B);
    } else if (bmi < 25.0) {
      color = const Color(0xFF10B981);
    } else if (bmi < 30.0) {
      color = const Color(0xFFEA580C);
    } else {
      color = const Color(0xFFDC2626);
    }
    return {'label': category, 'color': color};
  }

  Future<void> _showLogVitalsDialog(BuildContext context, bool isDark) async {
    final hrController = TextEditingController(text: _patient!.heartRate.toString());
    final bpController = TextEditingController(text: _patient!.bloodPressure);

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
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
                    Icon(Icons.monitor_heart_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 26),
                    const SizedBox(width: 12),
                    Text('Log Vitals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  ],
                ),
                const SizedBox(height: 20),
                _buildVitalsField(ctx, isDark, hrController, 'Heart Rate (bpm)', '60-100', TextInputType.number),
                const SizedBox(height: 14),
                _buildVitalsField(ctx, isDark, bpController, 'Blood Pressure', 'e.g. 120/80'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final hr = int.tryParse(hrController.text.trim());
                          final bp = bpController.text.trim();
                          if (hr == null || hr < 20 || hr > 300) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid heart rate value')),
                            );
                            return;
                          }
                          if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(bp)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid BP format. Use Systolic/Diastolic')),
                            );
                            return;
                          }
                          
                          try {
                            await IdService.updatePatientVitals(_patient!.id, hr, bp);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Vitals updated!'),
                                backgroundColor: isDark ? const Color(0xFF14B8A6) : Colors.teal.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          } catch (e) {
                            debugPrint('Error saving updated vitals: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitalsField(BuildContext ctx, bool isDark, TextEditingController ctrl, String label, String hint, [TextInputType? inputType]) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType ?? TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13),
        hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), width: 1.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_patient == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: isDark ? const Color(0xFF475569) : Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No patient profile loaded.',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final String patientName = _patient!.fullName;
    final String patientId = _patient!.id;
    final String bloodGroup = _patient!.bloodGroup;
    final String genderStr = _patient!.gender;
    final String ageStr = '${_patient!.age} yrs';
    final String weightStr = '${_patient!.weight} kg';
    
    final date = _patient!.registrationDate;
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String formattedDate = '${date.day} ${months[date.month - 1]} ${date.year}';

    // Compute vital classifications
    final hrClass = _classifyHR(_patient!.heartRate);
    final bpClass = _classifyBP(_patient!.bloodPressure);
    final wClass = _classifyWeight(_patient!.weight, _patient!.bmi);
    final bmiClass = _classifyBMI(_patient!.bmi, _patient!.bmiCategory);

    // Check if any vital is abnormal (Heart rate or Blood pressure)
    final bool anyAlert = hrClass['color'] != const Color(0xFF10B981) || bpClass['color'] != const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Patient Dashboard',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B), 
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF4F46E5),
              size: 22,
            ),
            onPressed: () {
              MediConnectApp.of(context)?.toggleTheme();
            },
          ),
          // Log Vitals shortcut
          IconButton(
            icon: Icon(Icons.monitor_heart_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 22),
            tooltip: 'Log Vitals',
            onPressed: () => _showLogVitalsDialog(context, isDark),
          ),
          IconButton(
            icon: Icon(Icons.home_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 24),
            tooltip: 'Home',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcoming greeting
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? const Color(0xFF818CF8).withOpacity(0.15) : const Color(0xFF4F46E5).withOpacity(0.08),
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), 
                      fontWeight: FontWeight.w900, 
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        patientName,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.06, end: 0),
            const SizedBox(height: 16),

            // === Vital Alert Banner ===
            if (anyAlert) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Abnormal vitals detected. Please consult a healthcare professional.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                          height: 1.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showLogVitalsDialog(context, isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Update', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
              const SizedBox(height: 14),
            ],

            // Premium Digital Hospital Card
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26.0),
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF312E81),
                          const Color(0xFF1E1B4B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFF4F46E5),
                          const Color(0xFF6366F1),
                          const Color(0xFF06B6D4),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : const Color(0xFF4F46E5).withOpacity(0.22),
                    blurRadius: 20.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26.0),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Opacity(
                        opacity: 0.08,
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 240,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Card Contents
                    Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.health_and_safety, color: Colors.white, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'MediConnect Card',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              _buildCardChip(),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            patientId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Courier',
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HOLDER NAME',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    patientName.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GENDER / BLOOD',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${genderStr.toUpperCase()} / $bloodGroup',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AGE / WEIGHT',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$ageStr / $weightStr',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ISSUE: $formattedDate',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack),
            const SizedBox(height: 16),

            // === ALLERGIES BANNER ===
            _buildAllergiesBanner(isDark)
                .animate()
                .fadeIn(delay: 250.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 24),

            // === VITALS SECTION ===
            _buildSectionHeader(isDark, 'Current Health Vitals', Icons.analytics_rounded),
            const SizedBox(height: 14),
            _buildVitalsRow(isDark, hrClass, bpClass, wClass, bmiClass)
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // === ACTIVE PRESCRIPTIONS ===
            _buildSectionHeader(isDark, 'Active Prescriptions', Icons.medication_rounded),
            const SizedBox(height: 14),
            _buildPrescriptionsList(isDark)
                .animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // === MEDICAL HISTORY ===
            _buildSectionHeader(isDark, 'Medical History', Icons.history_edu_rounded),
            const SizedBox(height: 14),
            _buildMedicalHistory(isDark)
                .animate()
                .fadeIn(delay: 540.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // === EMERGENCY CONTACT ===
            _buildSectionHeader(isDark, 'Emergency Contact', Icons.contact_phone_rounded),
            const SizedBox(height: 14),
            _buildEmergencyContactCard(isDark)
                .animate()
                .fadeIn(delay: 560.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 28),

            // === QUICK ACTIONS ===
            _buildSectionHeader(isDark, 'Quick Clinical Actions', Icons.grid_view_rounded),
            const SizedBox(height: 14),
            _buildQuickActions(context, isDark)
                .animate()
                .fadeIn(delay: 580.ms, duration: 500.ms)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCardChip() {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(left: 10, top: 0, bottom: 0, child: Container(width: 1, color: Colors.black12)),
          Positioned(left: 20, top: 0, bottom: 0, child: Container(width: 1, color: Colors.black12)),
          Positioned(left: 0, right: 0, top: 10, child: Container(height: 1, color: Colors.black12)),
          Positioned(left: 0, right: 0, top: 18, child: Container(height: 1, color: Colors.black12)),
          Center(
            child: Container(
              width: 14,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.amber.shade200.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFFD97706), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergiesBanner(bool isDark) {
    final allergies = _patient!.allergies;
    final hasAllergies = allergies.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hasAllergies 
            ? const Color(0xFFDC2626).withOpacity(0.08) 
            : const Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAllergies 
              ? const Color(0xFFDC2626).withOpacity(0.3) 
              : const Color(0xFF10B981).withOpacity(0.3)
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasAllergies ? Icons.warning_amber_rounded : Icons.shield_rounded,
            color: hasAllergies ? const Color(0xFFDC2626) : const Color(0xFF10B981),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAllergies ? 'CRITICAL ALLERGIES' : 'CLINICAL SAFETY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: hasAllergies ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAllergies 
                      ? allergies.join(', ') 
                      : 'No known drug or food allergies.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistory(bool isDark) {
    final conditions = _patient!.medicalConditions;
    if (conditions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 32, color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No medical history recorded',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: conditions.map((condition) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.medical_services_outlined, 
                size: 14, 
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)
              ),
              const SizedBox(width: 8),
              Text(
                condition,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmergencyContactCard(bool isDark) {
    final name = _patient!.emergencyContactName;
    final phone = _patient!.emergencyContactPhone;
    final relation = _patient!.emergencyContactRelation;
    
    final hasContact = name.isNotEmpty || phone.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : const Color(0xFFF1F5F9).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contact_phone_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: hasContact 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (relation.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                relation.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No emergency contact registered.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsRow(bool isDark, Map<String, dynamic> hrClass, Map<String, dynamic> bpClass, Map<String, dynamic> wClass, Map<String, dynamic> bmiClass) {
    final Color hrColor = hrClass['color'] as Color;
    final Color bpColor = bpClass['color'] as Color;
    final Color wColor = wClass['color'] as Color;
    final Color bmiColor = bmiClass['color'] as Color;

    final List<Map<String, dynamic>> vitals = [
      {
        'title': 'Heart Rate',
        'value': '${_patient!.heartRate} bpm',
        'status': hrClass['label'] as String,
        'statusColor': hrColor,
        'icon': Icons.favorite_rounded,
        'iconColor': hrColor,
        'pulseIcon': true,
      },
      {
        'title': 'Blood Pressure',
        'value': _patient!.bloodPressure,
        'status': bpClass['label'] as String,
        'statusColor': bpColor,
        'icon': Icons.speed_rounded,
        'iconColor': bpColor,
        'pulseIcon': false,
      },
      {
        'title': 'Weight Status',
        'value': '${_patient!.weight} kg',
        'status': wClass['label'] as String,
        'statusColor': wColor,
        'icon': Icons.monitor_weight_rounded,
        'iconColor': Colors.teal.shade500,
        'pulseIcon': false,
      },
      {
        'title': 'Body Mass Index',
        'value': _patient!.bmi > 0 ? _patient!.bmi.toStringAsFixed(1) : 'N/A',
        'status': bmiClass['label'] as String,
        'statusColor': bmiColor,
        'icon': Icons.health_and_safety_rounded,
        'iconColor': bmiColor,
        'pulseIcon': false,
      },
    ];

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: vitals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final v = vitals[index];
          final iconColor = v['iconColor'] as Color;
          final statusColor = v['statusColor'] as Color;
          final bool pulse = v['pulseIcon'] as bool;
          final bool isAbnormal = index < 2 && statusColor != const Color(0xFF10B981);

          final bool isEditing = (index == 0 && _isEditingHR) ||
              (index == 1 && _isEditingBP) ||
              (index == 2 && _isEditingW);
          final TextEditingController activeController = index == 0
              ? _hrEditController
              : index == 1
                  ? _bpEditController
                  : _wEditController;

          return Container(
            width: 155,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(22.0),
              border: Border.all(
                color: statusColor.withOpacity(isDark ? 0.55 : 0.45),
                width: isAbnormal ? 2.2 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(isDark ? 0.12 : 0.10),
                  blurRadius: isAbnormal ? 18 : 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        v['title'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index < 3) ...[
                          if (isEditing) ...[
                            GestureDetector(
                              onTap: () => _saveVitalField(index, activeController.text),
                              child: Icon(Icons.check_rounded, color: Colors.green.shade600, size: 16),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (index == 0) _isEditingHR = false;
                                  if (index == 1) _isEditingBP = false;
                                  if (index == 2) _isEditingW = false;
                                });
                              },
                              child: Icon(Icons.close_rounded, color: Colors.red.shade600, size: 16),
                            ),
                          ] else ...[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (index == 0) {
                                    _hrEditController.text = _patient!.heartRate.toString();
                                    _isEditingHR = true;
                                  } else if (index == 1) {
                                    _bpEditController.text = _patient!.bloodPressure;
                                    _isEditingBP = true;
                                  } else {
                                    _wEditController.text = _patient!.weight.toString();
                                    _isEditingW = true;
                                  }
                                });
                              },
                              child: Icon(
                                Icons.edit_rounded,
                                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                                size: 14,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            v['icon'] as IconData,
                            size: 14,
                            color: iconColor,
                          ).animate(
                            onPlay: (controller) {
                              if (pulse && !MediConnectApp.isTestMode) {
                                controller.repeat(reverse: true);
                              }
                            }
                          ).scale(end: const Offset(1.2, 1.2), duration: 600.ms, curve: Curves.easeInOut),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (index < 3 && isEditing)
                  SizedBox(
                    height: 38,
                    child: TextFormField(
                      controller: activeController,
                      keyboardType: index == 0
                          ? TextInputType.number
                          : index == 2
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      onFieldSubmitted: (val) => _saveVitalField(index, val),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        suffixText: index == 0 ? ' bpm' : index == 2 ? ' kg' : null,
                        suffixStyle: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    v['value'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        v['status'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrescriptionsList(bool isDark) {
    final prescriptions = _patient!.prescriptions;

    if (prescriptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 40, color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No active prescriptions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A doctor can add prescriptions via the Doctor Portal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: prescriptions.map((prescription) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(
              color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black12 : const Color(0xFFF1F5F9).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF818CF8).withOpacity(0.1) : const Color(0xFF4F46E5).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            prescription['medication'] ?? 'Medication',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (prescription['timeLeft'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              prescription['timeLeft']!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (prescription['dosage'] != null && prescription['dosage']!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        prescription['dosage']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                    if (prescription['instruction'] != null && prescription['instruction']!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        prescription['instruction']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAppointmentsBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32.0),
              topRight: Radius.circular(32.0),
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.transparent,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 36.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded, 
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Appointments',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white : const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded, 
                      size: 40, 
                      color: isDark ? const Color(0xFF475569) : Colors.grey.shade400
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Upcoming Appointments',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You don\'t have any visits scheduled at the moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: const Text('Online scheduling coming soon! Please contact your clinic.'),
                        backgroundColor: isDark ? const Color(0xFF14B8A6) : Colors.teal.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Request New Appointment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final List<Map<String, dynamic>> actions = [
      {'name': 'Log Vitals', 'icon': Icons.monitor_heart_rounded, 'desc': 'Update heart rate & BP', 'color': const Color(0xFFF43F5E)},
      {'name': 'My Profile', 'icon': Icons.person_rounded, 'desc': 'View & edit profile', 'color': const Color(0xFF0D9488)},
      {'name': 'Appointments', 'icon': Icons.calendar_month_rounded, 'desc': 'Book or view visits', 'color': const Color(0xFF6366F1)},
      {'name': 'Order Medicines', 'icon': Icons.local_pharmacy_rounded, 'desc': 'Refill active meds', 'color': const Color(0xFFFBBF24)},
    ];

    Widget buildCard(Map<String, dynamic> act) {
      final Color accentColor = act['color'] as Color;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (act['name'] == 'Log Vitals') {
                _showLogVitalsDialog(context, isDark);
                return;
              }
              if (act['name'] == 'My Profile') {
                Navigator.pushNamed(context, '/profile', arguments: _patient);
                return;
              }
              if (act['name'] == 'Appointments') {
                _showAppointmentsBottomSheet(context, isDark);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${act['name']} feature coming soon!',
                    style: TextStyle(color: isDark ? const Color(0xFF0F172A) : Colors.white),
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black12 : const Color(0xFFF1F5F9).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      act['icon'] as IconData,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    act['name'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    act['desc'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            buildCard(actions[0]),
            const SizedBox(width: 14),
            buildCard(actions[1]),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            buildCard(actions[2]),
            const SizedBox(width: 14),
            buildCard(actions[3]),
          ],
        ),
      ],
    );
  }
}
