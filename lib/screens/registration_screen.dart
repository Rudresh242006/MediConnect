import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import '../main.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../services/id_service.dart';
import '../widgets/success_dialog.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Details
  final _nameController = TextEditingController();
  DateTime? _selectedDOB;
  String? _selectedGender;
  bool _showGenderError = false;

  // Physical Metrics
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String? _selectedBloodGroup;
  bool _showBloodGroupError = false;

  // Contact Information
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  // Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String? _selectedEmergencyRelation;

  // Clinical: Allergies
  final List<String> _commonAllergens = [
    'Penicillin', 'Sulfa Drugs', 'Aspirin', 'Ibuprofen',
    'Latex', 'Peanuts', 'Shellfish', 'Eggs', 'Dairy',
  ];
  final Set<String> _selectedAllergies = {};
  final _customAllergyController = TextEditingController();
  bool _noKnownAllergies = false;

  // Clinical: Medical Conditions
  final List<String> _commonConditions = [
    'Diabetes', 'Hypertension', 'Asthma', 'Heart Disease',
    'Thyroid Disorder', 'Epilepsy', 'Cancer', 'Kidney Disease',
    'Liver Disease', 'Arthritis',
  ];
  final Set<String> _selectedConditions = {};

  // Optional Vitals
  final _heartRateController = TextEditingController(text: '72');
  final _bloodPressureController = TextEditingController(text: '120/80');

  // State
  bool _isLoading = false;
  int _currentStep = 0; // 0=Personal, 1=Contact, 2=Emergency, 3=Clinical, 4=Vitals
  final int _totalSteps = 5;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _relations = ['Spouse', 'Parent', 'Sibling', 'Child', 'Friend', 'Guardian', 'Other'];

  // FocusNodes for keyboard Enter-key step navigation
  final _nameFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _emergNameFocus = FocusNode();
  final _emergPhoneFocus = FocusNode();
  final _hrFocus = FocusNode();
  final _bpFocus = FocusNode();

  // Advance to next step (called by Enter key on last field of each step)
  void _advanceStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) setState(() => _currentStep++);
    } else {
      _handleRegistration();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _customAllergyController.dispose();
    _heartRateController.dispose();
    _bloodPressureController.dispose();
    _nameFocus.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _emergNameFocus.dispose();
    _emergPhoneFocus.dispose();
    _hrFocus.dispose();
    _bpFocus.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Discard Registration?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          ),
        ),
        content: Text(
          'Are you sure you want to go back? All entered patient details will be lost.',
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Editing',
              style: TextStyle(
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Personal
        final formValid = _formKey.currentState!.validate();
        setState(() {
          _showGenderError = _selectedGender == null;
          _showBloodGroupError = _selectedBloodGroup == null;
        });
        if (_selectedDOB == null) {
          _showErrorSnackBar('Please select date of birth');
          return false;
        }
        return formValid && _selectedGender != null && _selectedBloodGroup != null;
      case 1: // Contact
        return _formKey.currentState!.validate();
      case 2: // Emergency
        return _formKey.currentState!.validate();
      case 3: // Clinical
        return true; // Allergies and conditions are optional
      case 4: // Vitals
        return _formKey.currentState!.validate();
      default:
        return true;
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

  Future<void> _handleRegistration() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // ── Prepare patient fields ───────────────────────────────────────────
      final heartRate =
          int.tryParse(_heartRateController.text.trim()) ?? 72;
      final bloodPressure =
          _bloodPressureController.text.trim().isEmpty
              ? '120/80'
              : _bloodPressureController.text.trim();

      List<String> allAllergies = [];
      if (!_noKnownAllergies) {
        allAllergies = _selectedAllergies.toList();
        final custom = _customAllergyController.text.trim();
        if (custom.isNotEmpty) {
          allAllergies.addAll(
              custom.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
        }
      }

      // ── Save to Firebase (atomic ID generation + data write) ─────────────
      // IdService.savePatientToFirebase uses runTransaction on
      // patients/last_id — zero duplicate IDs, race-condition safe.
      final String patientId = await IdService.savePatientToFirebase(
        name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(),
        additionalData: {
          'fullName': _nameController.text.trim(),
          'dateOfBirth': _selectedDOB!.toIso8601String(),
          'weight': double.parse(_weightController.text.trim()),
          'height': double.parse(_heightController.text.trim()),
          'bloodGroup': _selectedBloodGroup!,
          'gender': _selectedGender!,
          'heartRate': heartRate,
          'bloodPressure': bloodPressure,
          'email': _emailController.text.trim(),
          'address': _addressController.text.trim(),
          'emergencyContactName': _emergencyNameController.text.trim(),
          'emergencyContactPhone': _emergencyPhoneController.text.trim(),
          'emergencyContactRelation': _selectedEmergencyRelation ?? '',
          'allergies': allAllergies,
          'medicalConditions': _selectedConditions.toList(),
          'prescriptions': <Map<String, String>>[],
        },
      );

      // ── Build Patient object with Firebase-generated ID ──────────────────
      final Patient newPatient = Patient(
        id: patientId,
        fullName: _nameController.text.trim(),
        dateOfBirth: _selectedDOB!,
        weight: double.parse(_weightController.text.trim()),
        height: double.parse(_heightController.text.trim()),
        bloodGroup: _selectedBloodGroup!,
        gender: _selectedGender!,
        registrationDate: DateTime.now(),
        heartRate: heartRate,
        bloodPressure: bloodPressure,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        emergencyContactRelation: _selectedEmergencyRelation ?? '',
        allergies: allAllergies,
        medicalConditions: _selectedConditions.toList(),
      );

      // ── Mirror to SharedPreferences (for Doctor Portal list view) ────────
      final prefs = await SharedPreferences.getInstance();
      final List<String> patientsJson =
          prefs.getStringList('registered_patients') ?? [];
      patientsJson.add(jsonEncode(newPatient.toJson()));
      await prefs.setStringList('registered_patients', patientsJson);
      await prefs.setString('active_patient_id', newPatient.id);

      setState(() => _isLoading = false);

      if (mounted) {
        // Show success dialog, then lock patient into dashboard
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SuccessDialog(patient: newPatient),
        );
        // After dialog closes: push dashboard and remove ALL previous routes
        // so patient cannot navigate back to the home/registration screen.
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
            arguments: newPatient,
          );
        }
      }

    } on FirebaseException catch (e) {
      // ── Firebase-specific errors ─────────────────────────────────────────
      setState(() => _isLoading = false);
      if (!mounted) return;

      final String message;
      if (e.code == 'network-request-failed' ||
          (e.message ?? '').toLowerCase().contains('network') ||
          (e.message ?? '').toLowerCase().contains('unavailable')) {
        message =
            'Registration failed. Please check your internet connection and try again.';
      } else {
        message = 'Server unavailable. Please try again in a moment.';
      }
      _showErrorSnackBar(message);

    } catch (e) {
      // ── Generic errors (retry exhausted, parse errors, etc.) ─────────────
      setState(() => _isLoading = false);
      if (!mounted) return;

      final errStr = e.toString().toLowerCase();
      final String message;
      if (errStr.contains('network') ||
          errStr.contains('internet') ||
          errStr.contains('connection') ||
          errStr.contains('socket') ||
          errStr.contains('unavailable')) {
        message =
            'Registration failed. Please check your internet connection and try again.';
      } else {
        message = 'Server unavailable. Please try again in a moment.';
      }
      _showErrorSnackBar(message);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF818CF8),
                    onPrimary: Color(0xFF0F172A),
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF4F46E5),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDOB = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep > 0) {
          setState(() => _currentStep--);
          return;
        }
        final navigator = Navigator.of(context);
        final shouldPop = await _showExitConfirmationDialog(context);
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: Column(
            children: [
              // Header
              _buildHeader(isDark),
              // Step Progress
              _buildStepIndicator(isDark),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: _buildCurrentStepContent(isDark),
                  ),
                ),
              ),
              // Bottom Navigation
              _buildBottomNav(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final stepTitles = ['Personal Details', 'Contact Info', 'Emergency Contact', 'Clinical History', 'Initial Vitals'];
    final stepSubtitles = ['Basic patient information', 'How to reach you', 'In case of emergency', 'Allergies & conditions', 'Optional: starting vitals'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
                return;
              }
              final navigator = Navigator.of(context);
              final shouldPop = await _showExitConfirmationDialog(context);
              if (shouldPop) {
                navigator.pop();
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 26),
              )
                  .animate(onPlay: (controller) {
                    if (!MediConnectApp.isTestMode) controller.repeat(reverse: true);
                  })
                  .scale(end: const Offset(1.15, 1.15), duration: 1200.ms, curve: Curves.easeInOut),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stepTitles[_currentStep],
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 4),
                    Text(
                      stepSubtitles[_currentStep],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ).animate().fadeIn(duration: 500.ms),
                  ],
                ),
              ),
              // Step counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentStep + 1} / $_totalSteps',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final bool isCompleted = index < _currentStep;
          final bool isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDetailsStep(isDark);
      case 1:
        return _buildContactInfoStep(isDark);
      case 2:
        return _buildEmergencyContactStep(isDark);
      case 3:
        return _buildClinicalHistoryStep(isDark);
      case 4:
        return _buildVitalsStep(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNav(bool isDark) {
    final isLastStep = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (isLastStep) {
                        _handleRegistration();
                      } else {
                        if (_validateCurrentStep()) {
                          setState(() => _currentStep++);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                disabledBackgroundColor: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)).withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isLastStep ? 'Register Patient' : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== STEP 1: PERSONAL DETAILS ==========
  Widget _buildPersonalDetailsStep(bool isDark) {
    return _buildStepCard(isDark, 'PATIENT DETAILS', [
      // Full Name
      TextFormField(
        controller: _nameController,
        focusNode: _nameFocus,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_heightFocus),
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'\-\.]")),
        ],
        decoration: _buildInputDecoration(context: context, label: 'Full Name *', icon: Icons.person_outline_rounded, hint: 'Enter first and last name'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter patient\'s full name';
          if (value.trim().length < 3) return 'Name must be at least 3 characters';
          if (!RegExp(r"^[a-zA-Z\s'\-\.]+$").hasMatch(value)) return 'Name should only contain letters, hyphens, or apostrophes';
          return null;
        },
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      // Date of Birth
      GestureDetector(
        onTap: _pickDateOfBirth,
        child: AbsorbPointer(
          child: TextFormField(
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: _buildInputDecoration(
              context: context,
              label: 'Date of Birth *',
              icon: Icons.cake_rounded,
              hint: 'Tap to select',
            ).copyWith(
              suffixIcon: Icon(Icons.calendar_month_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 20),
            ),
            controller: TextEditingController(
              text: _selectedDOB != null
                  ? '${_selectedDOB!.day.toString().padLeft(2, '0')} / ${_selectedDOB!.month.toString().padLeft(2, '0')} / ${_selectedDOB!.year}'
                  : '',
            ),
            validator: (_) => _selectedDOB == null ? 'Please select date of birth' : null,
          ),
        ),
      ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      // Height & Weight Row
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _heightController,
              focusNode: _heightFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_weightFocus),
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _buildInputDecoration(context: context, label: 'Height (cm) *', icon: Icons.height_rounded, hint: 'e.g. 170'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                final h = double.tryParse(value.trim());
                if (h == null || h < 30 || h > 300) return 'Invalid (30-300)';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _weightController,
              focusNode: _weightFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
                _advanceStep();
              },
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _buildInputDecoration(context: context, label: 'Weight (kg) *', icon: Icons.monitor_weight_outlined, hint: 'e.g. 72.5'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                final w = double.tryParse(value.trim());
                if (w == null || w < 1 || w > 500) return 'Invalid (1-500)';
                return null;
              },
            ),
          ),
        ],
      ).animate().fadeIn(delay: 260.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 24),

      // Gender
      _buildGenderSelector(isDark).animate().fadeIn(delay: 340.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 24),

      // Blood Group
      _buildBloodGroupSelector(isDark).animate().fadeIn(delay: 420.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
    ]);
  }

  // ========== STEP 2: CONTACT INFORMATION ==========
  Widget _buildContactInfoStep(bool isDark) {
    return _buildStepCard(isDark, 'CONTACT INFORMATION', [
      TextFormField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
          LengthLimitingTextInputFormatter(15),
        ],
        decoration: _buildInputDecoration(context: context, label: 'Phone Number *', icon: Icons.phone_rounded, hint: 'e.g. +91 98765 43210'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter phone number';
          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length < 10) return 'Enter a valid phone number (min 10 digits)';
          return null;
        },
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      TextFormField(
        controller: _emailController,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_addressFocus),
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        decoration: _buildInputDecoration(context: context, label: 'Email Address *', icon: Icons.email_rounded, hint: 'e.g. patient@example.com'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter email address';
          if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(value.trim())) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      TextFormField(
        controller: _addressController,
        focusNode: _addressFocus,
        keyboardType: TextInputType.streetAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) {
          FocusScope.of(context).unfocus();
          _advanceStep();
        },
        maxLines: 2,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        decoration: _buildInputDecoration(context: context, label: 'Address *', icon: Icons.location_on_rounded, hint: 'City, State, PIN Code'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter address';
          if (value.trim().length < 5) return 'Address must be at least 5 characters';
          return null;
        },
      ).animate().fadeIn(delay: 260.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
    ]);
  }

  // ========== STEP 3: EMERGENCY CONTACT ==========
  Widget _buildEmergencyContactStep(bool isDark) {
    return _buildStepCard(isDark, 'EMERGENCY CONTACT', [
      // Info banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This person will be contacted in case of a medical emergency.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E), height: 1.4),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
      const SizedBox(height: 20),

      TextFormField(
        controller: _emergencyNameController,
        focusNode: _emergNameFocus,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emergPhoneFocus),
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'\-\.]"))],
        decoration: _buildInputDecoration(context: context, label: 'Contact Name *', icon: Icons.person_outline_rounded, hint: 'Full name'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter emergency contact name';
          return null;
        },
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      TextFormField(
        controller: _emergencyPhoneController,
        focusNode: _emergPhoneFocus,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) {
          FocusScope.of(context).unfocus();
          _advanceStep();
        },
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
          LengthLimitingTextInputFormatter(15),
        ],
        decoration: _buildInputDecoration(context: context, label: 'Contact Phone *', icon: Icons.phone_rounded, hint: 'Phone number'),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Please enter emergency contact phone';
          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length < 10) return 'Enter a valid phone number';
          return null;
        },
      ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
      const SizedBox(height: 20),

      // Relationship selector
      _buildRelationshipSelector(isDark).animate().fadeIn(delay: 260.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
    ]);
  }

  // ========== STEP 4: CLINICAL HISTORY ==========
  Widget _buildClinicalHistoryStep(bool isDark) {
    return Column(
      children: [
        // Allergies Section
        _buildStepCard(isDark, 'KNOWN ALLERGIES', [
          // No Known Allergies toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _noKnownAllergies = !_noKnownAllergies;
                if (_noKnownAllergies) {
                  _selectedAllergies.clear();
                  _customAllergyController.clear();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _noKnownAllergies
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _noKnownAllergies
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: _noKnownAllergies ? 2.0 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _noKnownAllergies ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: _noKnownAllergies ? const Color(0xFF10B981) : (isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No Known Allergies (NKA)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _noKnownAllergies ? FontWeight.bold : FontWeight.w500,
                      color: _noKnownAllergies
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_noKnownAllergies) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonAllergens.map((allergen) {
                final isSelected = _selectedAllergies.contains(allergen);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAllergies.remove(allergen);
                      } else {
                        _selectedAllergies.add(allergen);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.8 : 1.2,
                      ),
                    ),
                    child: Text(
                      allergen,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _customAllergyController,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
              decoration: _buildInputDecoration(context: context, label: 'Other Allergies', icon: Icons.add_circle_outline_rounded, hint: 'Separate with commas'),
            ),
          ],
        ]),
        const SizedBox(height: 20),

        // Medical Conditions Section
        _buildStepCard(isDark, 'PRE-EXISTING CONDITIONS', [
          Text(
            'Select any that apply (optional)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonConditions.map((condition) {
              final isSelected = _selectedConditions.contains(condition);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedConditions.remove(condition);
                    } else {
                      _selectedConditions.add(condition);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF818CF8).withValues(alpha: 0.15) : const Color(0xFF4F46E5).withValues(alpha: 0.08))
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.8 : 1.2,
                    ),
                  ),
                  child: Text(
                    condition,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ],
    );
  }

  // ========== STEP 5: VITALS ==========
  Widget _buildVitalsStep(bool isDark) {
    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These vitals are optional. Default values will be used if left unchanged. You can update them anytime from your dashboard.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),

        _buildStepCard(isDark, 'INITIAL VITALS', [
          TextFormField(
            controller: _heartRateController,
            focusNode: _hrFocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_bpFocus),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: _buildInputDecoration(context: context, label: 'Heart Rate (bpm)', icon: Icons.favorite_outline_rounded, hint: 'e.g. 72'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final hr = int.tryParse(value.trim());
              if (hr == null || hr < 20 || hr > 300) return 'Enter valid heart rate (20-300)';
              return null;
            },
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
          const SizedBox(height: 20),

          TextFormField(
            controller: _bloodPressureController,
            focusNode: _bpFocus,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              FocusScope.of(context).unfocus();
              _handleRegistration();
            },
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: _buildInputDecoration(context: context, label: 'Blood Pressure', icon: Icons.speed_rounded, hint: 'e.g. 120/80'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(value.trim())) {
                return 'Format must be Systolic/Diastolic e.g. 120/80';
              }
              final parts = value.trim().split('/');
              final systolic = int.tryParse(parts[0]);
              final diastolic = int.tryParse(parts[1]);
              if (systolic == null || diastolic == null ||
                  systolic < 50 || systolic > 300 ||
                  diastolic < 30 || diastolic > 200) {
                return 'Enter valid blood pressure values';
              }
              return null;
            },
          ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideX(begin: 0.08, end: 0),
        ]),

        const SizedBox(height: 20),

        // Security Note
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              'Data is securely stored offline in device sandbox.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ========== REUSABLE WIDGETS ==========
  Widget _buildStepCard(bool isDark, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF6366F1).withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : Colors.indigo.shade900.withValues(alpha: 0.6),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGenderSelector(bool isDark) {
    final List<Map<String, dynamic>> genders = [
      {'name': 'Male', 'icon': Icons.male_rounded},
      {'name': 'Female', 'icon': Icons.female_rounded},
      {'name': 'Other', 'icon': Icons.transgender_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GENDER *',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : Colors.indigo.shade900.withValues(alpha: 0.6),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: genders.map((g) {
            final name = g['name'] as String;
            final icon = g['icon'] as IconData;
            final isSelected = _selectedGender == name;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGender = name;
                    _showGenderError = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF818CF8).withValues(alpha: 0.15) : const Color(0xFF4F46E5).withValues(alpha: 0.08))
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: isSelected ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)), size: 24),
                      const SizedBox(height: 6),
                      Text(name, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? (isDark ? Colors.white : const Color(0xFF1E293B)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_showGenderError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text('Please select gender', style: TextStyle(color: Colors.red.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildBloodGroupSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOOD GROUP *',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : Colors.indigo.shade900.withValues(alpha: 0.6),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _bloodGroups.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final group = _bloodGroups[index];
              final isSelected = _selectedBloodGroup == group;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBloodGroup = group;
                    _showBloodGroupError = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF818CF8).withValues(alpha: 0.15) : const Color(0xFF4F46E5).withValues(alpha: 0.08))
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(group, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? (isDark ? Colors.white : const Color(0xFF1E293B)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)))),
                  ),
                ),
              );
            },
          ),
        ),
        if (_showBloodGroupError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text('Please select a blood group', style: TextStyle(color: Colors.red.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildRelationshipSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATIONSHIP *',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : Colors.indigo.shade900.withValues(alpha: 0.6),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _relations.map((relation) {
            final isSelected = _selectedEmergencyRelation == relation;
            return GestureDetector(
              onTap: () => setState(() => _selectedEmergencyRelation = relation),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF818CF8).withValues(alpha: 0.15) : const Color(0xFF4F46E5).withValues(alpha: 0.08))
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                ),
                child: Text(
                  relation,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : Colors.indigo.shade900.withValues(alpha: 0.5),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
        fontWeight: FontWeight.bold,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: Colors.red.shade200, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2.0),
      ),
      errorStyle: TextStyle(color: Colors.red.shade500, fontWeight: FontWeight.w600),
    );
  }
}
