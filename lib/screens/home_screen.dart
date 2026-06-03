import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../models/patient.dart';
import '../services/id_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Patient? _lastPatient;
  bool _isCheckingPatient = true;

  @override
  void initState() {
    super.initState();
    _loadLastPatient();
  }

  Future<void> _loadLastPatient() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if a doctor is logged in
      final doctorId = prefs.getString('logged_in_doctor_id');
      if (doctorId != null && doctorId.isNotEmpty && mounted) {
        Navigator.pushReplacementNamed(context, '/doctor');
        return;
      }

      // 2. Check if a patient is logged in
      final activePatientId = prefs.getString('active_patient_id');
      if (activePatientId != null && activePatientId.isNotEmpty && mounted) {
        final patientsJson = prefs.getStringList('registered_patients') ?? [];
        Patient? loggedInPatient;
        for (var pj in patientsJson) {
          try {
            final pMap = jsonDecode(pj) as Map<String, dynamic>;
            if (pMap['id'] == activePatientId) {
              loggedInPatient = Patient.fromJson(pMap);
              break;
            }
          } catch (_) {}
        }
        if (loggedInPatient != null) {
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: loggedInPatient,
          );
          return;
        }
      }

      // 3. Normal flow: Load last registered patient preview card
      final patientsJson = prefs.getStringList('registered_patients') ?? [];
      if (patientsJson.isNotEmpty) {
        final lastMap = jsonDecode(patientsJson.last) as Map<String, dynamic>;
        final localPatient = Patient.fromJson(lastMap);
        
        setState(() {
          _lastPatient = localPatient;
        });

        final cloudPatient = await IdService.getPatientById(localPatient.id);
        if (cloudPatient != null && mounted) {
          setState(() {
            _lastPatient = cloudPatient;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading last patient or redirecting: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingPatient = false);
      }
    }
  }

  void _showDoctorPortal(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Top background gradient glow
            Positioned(
              top: -150,
              left: -50,
              right: -50,
              child: Container(
                height: 350,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      isDark 
                          ? const Color(0xFF312E81).withOpacity(0.25)
                          : const Color(0xFF818CF8).withOpacity(0.2),
                      isDark
                          ? const Color(0xFF0F172A).withOpacity(0)
                          : const Color(0xFFF8FAFC).withOpacity(0),
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
            
            // Theme Toggle Button
            Positioned(
              top: 16,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : const Color(0xFFCBD5E1).withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? Colors.amber : const Color(0xFF4F46E5),
                    size: 22,
                  ),
                  onPressed: () {
                    MediConnectApp.of(context)?.toggleTheme();
                  },
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // MediConnect Logo
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                                ? const Color(0xFF818CF8).withOpacity(0.2)
                                : const Color(0xFF818CF8).withOpacity(0.5),
                            blurRadius: 24.0,
                            spreadRadius: 4.0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        size: 48,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      ),
                    )
                        .animate(onPlay: (controller) {
                          if (!MediConnectApp.isTestMode) {
                            controller.repeat(reverse: true);
                          }
                        })
                        .scale(duration: 800.ms, curve: Curves.elasticOut)
                        .custom(
                          duration: 1200.ms,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 1.0 + (value * 0.05),
                              child: child,
                            );
                          },
                        ),
                  ),
                  const SizedBox(height: 28),

                  // Welcome Typography
                  Text(
                    'MediConnect',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: 0.8,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Connecting Care, Anywhere, Anytime',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      letterSpacing: 0.2,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 40),

                  // === "Enter Patient Portal" quick access if profile exists ===
                  if (!_isCheckingPatient && _lastPatient != null) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('active_patient_id', _lastPatient!.id);
                          if (context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/dashboard',
                              arguments: _lastPatient,
                            ).then((_) {
                              _loadLastPatient();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                                  : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                child: Text(
                                  _lastPatient!.fullName.isNotEmpty
                                      ? _lastPatient!.fullName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Continue as',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    Text(
                                      _lastPatient!.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 16),
                  ],

                  // Portal Selection Section Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SELECT PORTAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 12),

                  // Patient Card Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/register').then((_) {
                          // Refresh patient data when returning from registration
                          _loadLastPatient();
                        });
                      },
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        padding: const EdgeInsets.all(22.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black26
                                  : const Color(0xFF6366F1).withOpacity(0.06),
                              blurRadius: 16.0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF818CF8).withOpacity(0.1)
                                    : const Color(0xFF4F46E5).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.assignment_ind_rounded,
                                size: 28,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'I am a Patient',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _lastPatient != null
                                        ? 'Register new patient or switch profile'
                                        : 'Register, view digital card, track medical history',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 16),

                  // Doctor Card Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDoctorPortal(context),
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        padding: const EdgeInsets.all(22.0),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF1E293B).withOpacity(0.5) 
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 10.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF14B8A6).withOpacity(0.1)
                                    : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.medical_services_rounded,
                                size: 28,
                                color: isDark ? const Color(0xFF14B8A6) : Colors.teal.shade600,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'I am a Doctor',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage patients, prescribe, review diagnostics',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF14B8A6) : Colors.teal.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 750.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  const Spacer(flex: 3),
                  
                  // Footer Branding
                  Text(
                    'MediConnect v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
                      letterSpacing: 0.8,
                    ),
                  ).animate().fadeIn(delay: 900.ms),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
