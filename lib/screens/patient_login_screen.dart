import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/id_service.dart';
import '../utils/form_enter_navigation.dart';
import '../utils/prefixed_id_formatter.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  bool _isLoading = false;

  static const _prefix = 'P-';

  @override
  void initState() {
    super.initState();
    _idController.text = _prefix;
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final patientId = _idController.text.trim().toUpperCase();
      final patient = await IdService.getPatientById(patientId);

      if (patient == null) {
        setState(() => _isLoading = false);
        _showSnack('Patient ID not found. Please check and try again.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final patientsJson = prefs.getStringList('registered_patients') ?? [];
      final encoded = jsonEncode(patient.toJson());
      var found = false;
      for (var i = 0; i < patientsJson.length; i++) {
        try {
          final map = jsonDecode(patientsJson[i]) as Map<String, dynamic>;
          if (map['id'] == patient.id) {
            patientsJson[i] = encoded;
            found = true;
            break;
          }
        } catch (_) {}
      }
      if (!found) patientsJson.add(encoded);
      await prefs.setStringList('registered_patients', patientsJson);
      await prefs.setString('active_patient_id', patient.id);

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
        arguments: patient,
      );
    } catch (_) {
      setState(() => _isLoading = false);
      _showSnack('Login failed. Please check your connection and try again.');
    }
  }

  InputDecoration _inp(BuildContext ctx, String label, IconData icon,
      {String? hint}) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
      ),
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.amber : const Color(0xFF4F46E5),
                    ),
                    onPressed: () => MediConnectApp.of(context)?.toggleTheme(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Login',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your Patient ID to open your dashboard.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ).animate().fadeIn(delay: 80.ms),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _idController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => FormEnterNavigation.onFieldDone(
                          context,
                          onSubmit: () => _handleLogin(),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          PrefixedIdTextInputFormatter(prefix: _prefix),
                        ],
                        decoration: _inp(
                          context,
                          'Patient ID *',
                          Icons.badge_outlined,
                          hint: 'P-A0A0A0A0A1',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your Patient ID';
                          }
                          if (!RegExp(r'^P-[A-Z0-9]{10}$')
                              .hasMatch(v.trim().toUpperCase())) {
                            return 'Invalid format — must be P-XXXXXXXXXX';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 120.ms).slideX(begin: 0.06),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF4F46E5),
                            foregroundColor:
                                isDark ? const Color(0xFF0F172A) : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _isLoading ? 'Verifying...' : 'Login to Dashboard',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: Text(
                            'New patient? Register here',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
