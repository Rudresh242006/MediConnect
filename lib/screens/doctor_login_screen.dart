import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/id_service.dart';
import '../main.dart';
import '../utils/form_scroll_helper.dart';
import '../utils/form_enter_navigation.dart';
import '../utils/prefixed_id_formatter.dart';

/// Doctor Login/Registration Screen
///
/// Flow:
///   1. Doctor chooses "Login" (existing) or "Register" (new).
///   2. Register: fills full details → saved to Firebase → stored in prefs.
///   3. Login: enters Doctor ID + License No → validated against Firebase.
///   4. On success: navigate to DoctorScreen (patient portal).

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = false;

  // ── Registration fields ──────────────────────────────────────────────────
  final _regFormKey = GlobalKey<FormState>();
  final _regNameController = TextEditingController();
  final _regLicenseController = TextEditingController();
  final _regSpecController = TextEditingController();
  final _regHospitalController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regExpController = TextEditingController();
  String? _selectedGender;
  String? _selectedDepartment;
  bool _showRegGenderError = false;
  int _regStep = 0; // 0 = personal, 1 = professional

  final _regScrollController = ScrollController();
  final _regNameFieldKey = GlobalKey<FormFieldState<String>>();
  final _regPhoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _regEmailFieldKey = GlobalKey<FormFieldState<String>>();
  final _regGenderSectionKey = GlobalKey();
  final _regLicenseFieldKey = GlobalKey<FormFieldState<String>>();
  final _regDeptFieldKey = GlobalKey<FormFieldState<String>>();
  final _regSpecFieldKey = GlobalKey<FormFieldState<String>>();
  final _regHospitalFieldKey = GlobalKey<FormFieldState<String>>();
  final _regExpFieldKey = GlobalKey<FormFieldState<String>>();

  // ── Login fields ─────────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _loginIdController = TextEditingController();
  final _loginLicenseController = TextEditingController();
  final _loginIdFocus = FocusNode();
  final _loginLicenseFocus = FocusNode();
  final _regNameFocus = FocusNode();
  final _regPhoneFocus = FocusNode();
  final _regEmailFocus = FocusNode();
  final _regLicenseFocus = FocusNode();
  final _regSpecFocus = FocusNode();
  final _regHospitalFocus = FocusNode();
  final _regExpFocus = FocusNode();

  final List<String> _departments = [
    'General Medicine',
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Obstetrics & Gynecology',
    'Dermatology',
    'Psychiatry',
    'Oncology',
    'Radiology',
    'Emergency Medicine',
    'Anesthesiology',
    'Surgery',
    'ENT',
    'Ophthalmology',
    'Urology',
    'Nephrology',
    'Pulmonology',
    'Endocrinology',
    'Rheumatology',
  ];

  static const _doctorIdPrefix = 'D-';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loginIdController.text = _doctorIdPrefix;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameController.dispose();
    _regLicenseController.dispose();
    _regSpecController.dispose();
    _regHospitalController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regExpController.dispose();
    _loginIdController.dispose();
    _loginLicenseController.dispose();
    _loginIdFocus.dispose();
    _loginLicenseFocus.dispose();
    _regNameFocus.dispose();
    _regPhoneFocus.dispose();
    _regEmailFocus.dispose();
    _regLicenseFocus.dispose();
    _regSpecFocus.dispose();
    _regHospitalFocus.dispose();
    _regExpFocus.dispose();
    _regScrollController.dispose();
    super.dispose();
  }

  Future<void> _advanceRegStep() async {
    if (await _validateRegStep()) {
      setState(() => _regStep = 1);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  InputDecoration _inp(BuildContext ctx, String label, IconData icon,
      {String? hint}) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon,
          size: 20,
          color:
              isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF818CF8)
                : const Color(0xFF4F46E5),
            width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }

  // ── REGISTRATION ─────────────────────────────────────────────────────────

  Future<bool> _validateRegStep() async {
    _regFormKey.currentState!.validate();

    if (_regStep == 0) {
      if (await FormScrollHelper.scrollToFirstInvalidField([
        _regNameFieldKey,
        _regPhoneFieldKey,
        _regEmailFieldKey,
      ])) {
        return false;
      }
      setState(() => _showRegGenderError = _selectedGender == null);
      if (_selectedGender == null) {
        await FormScrollHelper.reveal(_regGenderSectionKey);
        return false;
      }
      return true;
    }

    if (await FormScrollHelper.scrollToFirstInvalidField([
      _regLicenseFieldKey,
      _regDeptFieldKey,
      _regSpecFieldKey,
      _regHospitalFieldKey,
      _regExpFieldKey,
    ])) {
      return false;
    }
    if (_selectedDepartment == null) {
      await FormScrollHelper.reveal(_regDeptFieldKey);
      return false;
    }
    return true;
  }

  Future<void> _handleRegister() async {
    if (!await _validateRegStep()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final doctorId = await IdService.saveDoctorToFirebase(
        name: _regNameController.text.trim(),
        mobile: _regPhoneController.text.trim(),
        additionalData: {
          'fullName': _regNameController.text.trim(),
          'licenseNumber': _regLicenseController.text.trim().toUpperCase(),
          'specialization': _regSpecController.text.trim(),
          'department': _selectedDepartment ?? '',
          'hospital': _regHospitalController.text.trim(),
          'email': _regEmailController.text.trim(),
          'yearsOfExperience': int.tryParse(_regExpController.text.trim()) ?? 0,
          'gender': _selectedGender ?? '',
        },
      );

      // Cache doctor session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_doctor_id', doctorId);
      await prefs.setString('logged_in_doctor_name', _regNameController.text.trim());
      await prefs.setString('logged_in_doctor_license', _regLicenseController.text.trim().toUpperCase());

      setState(() => _isLoading = false);

      if (mounted) {
        _showSnack(
          'Welcome Dr. ${_regNameController.text.trim()}! Your ID is $doctorId',
          isError: false,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/doctor');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Registration failed. Please check your connection and try again.');
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final doctorId = _loginIdController.text.trim().toUpperCase();
      final license = _loginLicenseController.text.trim().toUpperCase();

      final docData = await IdService.getDoctorById(doctorId);

      if (docData == null) {
        setState(() => _isLoading = false);
        _showSnack('Doctor ID not found. Please check and try again.');
        return;
      }

      final storedLicense =
          ((docData['licenseNumber'] ?? '') as String).toUpperCase();
      if (storedLicense != license) {
        setState(() => _isLoading = false);
        _showSnack('Invalid license number. Please try again.');
        return;
      }

      // Cache doctor session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_doctor_id', doctorId);
      await prefs.setString(
          'logged_in_doctor_name', (docData['fullName'] ?? 'Doctor') as String);
      await prefs.setString('logged_in_doctor_license', license);

      setState(() => _isLoading = false);

      if (mounted) {
        _showSnack(
          'Welcome back, Dr. ${docData['fullName'] ?? 'Doctor'}!',
          isError: false,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/doctor');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Login failed. Please check your connection and try again.');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 52, 24, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0D9488), const Color(0xFF0F172A)]
                    : [const Color(0xFF0D9488), const Color(0xFF134E4A)],
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
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Doctor Portal',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Login or register your profile',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
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
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0),

          // ── Tab Bar ──────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF0D9488).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade600,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Register'),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),

          // ── Tab Views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoginTab(isDark),
                _buildRegisterTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LOGIN TAB ─────────────────────────────────────────────────────────────

  Widget _buildLoginTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _sectionHeader(isDark, 'DOCTOR CREDENTIALS', Icons.lock_outline_rounded),
            const SizedBox(height: 20),

            // Doctor ID field
            TextFormField(
              controller: _loginIdController,
              focusNode: _loginIdFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FormEnterNavigation.focusNext(context, _loginLicenseFocus),
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold),
              inputFormatters: [
                PrefixedIdTextInputFormatter(prefix: _doctorIdPrefix),
              ],
              decoration: _inp(
                context,
                'Doctor ID *',
                Icons.badge_outlined,
                hint: 'D-A0A0A0A0A1',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your Doctor ID';
                }
                if (!RegExp(r'^D-[A-Z0-9]{10}$')
                    .hasMatch(v.trim().toUpperCase())) {
                  return 'Invalid format — must be D-XXXXXXXXXX';
                }
                return null;
              },
            ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.08),
            const SizedBox(height: 16),

            // License Number field
            TextFormField(
              controller: _loginLicenseController,
              focusNode: _loginLicenseFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FormEnterNavigation.onFieldDone(
                context,
                onSubmit: () => _handleLogin(),
              ),
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: 1.2),
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: _inp(
                context,
                'Medical License Number *',
                Icons.verified_outlined,
                hint: 'e.g. MCI-123456',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your license number';
                }
                if (v.trim().length < 5) {
                  return 'License number must be at least 5 characters';
                }
                return null;
              },
            ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.08),
            const SizedBox(height: 32),

            // Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF0D9488).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  _isLoading ? 'Verifying...' : 'Login to Portal',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF0D9488).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF0D9488), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New here? Switch to the Register tab to create your doctor profile and get your unique Doctor ID.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  // ── REGISTER TAB ──────────────────────────────────────────────────────────

  Widget _buildRegisterTab(bool isDark) {
    return Column(
      children: [
        // Step indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _stepDot(isDark, 0, 'Personal'),
              Expanded(
                child: Container(
                  height: 2,
                  color: _regStep >= 1
                      ? const Color(0xFF0D9488)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
              _stepDot(isDark, 1, 'Professional'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Form content
        Expanded(
          child: SingleChildScrollView(
            controller: _regScrollController,
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Form(
              key: _regFormKey,
              child: _regStep == 0
                  ? _buildRegStep0(isDark)
                  : _buildRegStep1(isDark),
            ),
          ),
        ),

        // Bottom nav
        _buildRegBottomNav(isDark),
      ],
    );
  }

  Widget _stepDot(bool isDark, int step, String label) {
    final bool isActive = _regStep >= step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF0D9488)
                : (isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0D9488)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
              width: 2,
            ),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive
                ? const Color(0xFF0D9488)
                : (isDark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  // Step 0: Personal Details
  Widget _buildRegStep0(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isDark, 'PERSONAL INFORMATION', Icons.person_outline_rounded),
        const SizedBox(height: 20),

        // Full Name
        TextFormField(
          key: _regNameFieldKey,
          controller: _regNameController,
          focusNode: _regNameFocus,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FormEnterNavigation.focusNext(context, _regPhoneFocus),
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'\-\.]")),
          ],
          decoration: _inp(context, 'Full Name *', Icons.person_outline_rounded,
              hint: 'Dr. First Last'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter your full name';
            if (v.trim().length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Phone
        TextFormField(
          key: _regPhoneFieldKey,
          controller: _regPhoneController,
          focusNode: _regPhoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FormEnterNavigation.focusNext(context, _regEmailFocus),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: _inp(context, 'Phone Number *', Icons.phone_rounded,
              hint: '+91 98765 43210'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter phone number';
            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length < 10) return 'Enter a valid phone number';
            return null;
          },
        ).animate().fadeIn(delay: 160.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          key: _regEmailFieldKey,
          controller: _regEmailController,
          focusNode: _regEmailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FormEnterNavigation.onFieldDone(
            context,
            onSubmit: () => _advanceRegStep(),
          ),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          decoration: _inp(context, 'Email Address *', Icons.email_rounded,
              hint: 'doctor@hospital.com'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter email address';
            if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$')
                .hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.08),
        const SizedBox(height: 20),

        // Gender selector
        KeyedSubtree(
          key: _regGenderSectionKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(isDark, 'GENDER', Icons.wc_rounded),
              const SizedBox(height: 10),
              Row(
          children: ['Male', 'Female', 'Other'].map((g) {
            final selected = _selectedGender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedGender = g;
                  _showRegGenderError = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF0D9488)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF0D9488)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    g,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
              if (_showRegGenderError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Please select your gender',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 280.ms),
        const SizedBox(height: 32),
      ],
    );
  }

  // Step 1: Professional Details
  Widget _buildRegStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isDark, 'PROFESSIONAL DETAILS', Icons.work_outline_rounded),
        const SizedBox(height: 20),

        // License Number
        TextFormField(
          key: _regLicenseFieldKey,
          controller: _regLicenseController,
          focusNode: _regLicenseFocus,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FormEnterNavigation.focusNext(context, _regSpecFocus),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: 1.2),
          decoration: _inp(context, 'Medical License Number *',
              Icons.verified_outlined,
              hint: 'e.g. MCI-123456'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'License number is required';
            }
            if (v.trim().length < 5) {
              return 'License number must be at least 5 characters';
            }
            return null;
          },
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Department dropdown
        DropdownButtonFormField<String>(
          key: _regDeptFieldKey,
          value: _selectedDepartment,
          decoration: _inp(context, 'Department / Specialization *',
              Icons.local_hospital_outlined),
          dropdownColor:
              isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 14),
          items: _departments
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedDepartment = v),
          validator: (v) =>
              v == null ? 'Please select your department' : null,
        ).animate().fadeIn(delay: 160.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Specialization (sub-specialty / title)
        TextFormField(
          key: _regSpecFieldKey,
          controller: _regSpecController,
          focusNode: _regSpecFocus,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FormEnterNavigation.focusNext(context, _regHospitalFocus),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          decoration: _inp(context, 'Sub-specialty / Designation *',
              Icons.star_outline_rounded,
              hint: 'e.g. Interventional Cardiologist'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Please enter your designation or sub-specialty';
            }
            return null;
          },
        ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Hospital
        TextFormField(
          key: _regHospitalFieldKey,
          controller: _regHospitalController,
          focusNode: _regHospitalFocus,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FormEnterNavigation.focusNext(context, _regExpFocus),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          decoration: _inp(context, 'Hospital / Clinic Name *',
              Icons.business_outlined,
              hint: 'e.g. City Medical Center'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Please enter your hospital or clinic name';
            }
            return null;
          },
        ).animate().fadeIn(delay: 280.ms).slideX(begin: 0.08),
        const SizedBox(height: 16),

        // Years of experience
        TextFormField(
          key: _regExpFieldKey,
          controller: _regExpController,
          focusNode: _regExpFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FormEnterNavigation.onFieldDone(
            context,
            onSubmit: () => _handleRegister(),
          ),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: _inp(context, 'Years of Experience *',
              Icons.timeline_rounded,
              hint: 'e.g. 10'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Please enter years of experience';
            }
            final yr = int.tryParse(v.trim());
            if (yr == null || yr < 0 || yr > 60) {
              return 'Enter a valid number (0-60)';
            }
            return null;
          },
        ).animate().fadeIn(delay: 340.ms).slideX(begin: 0.08),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRegBottomNav(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (_regStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _regStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          if (_regStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_regStep == 0) {
                        if (await _validateRegStep()) {
                          setState(() => _regStep = 1);
                        }
                      } else {
                        await _handleRegister();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF0D9488).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      _regStep == 0 ? 'Continue' : 'Register & Login',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Shared UI: section header label
  Widget _sectionHeader(bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon,
            size: 15,
            color: isDark
                ? const Color(0xFF0D9488)
                : const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark
                ? const Color(0xFF0D9488)
                : const Color(0xFF0D9488),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
