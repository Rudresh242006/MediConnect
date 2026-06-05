import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../services/id_service.dart';
import '../utils/form_enter_navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Patient? _patient;
  bool _isLoading = true;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  String _emergencyRelation = 'Spouse';

  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _emergencyNameFocus = FocusNode();
  final _emergencyPhoneFocus = FocusNode();

  final List<String> _relationships = [
    'Spouse',
    'Parent',
    'Child',
    'Sibling',
    'Friend',
    'Guardian',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPatientData();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _emergencyNameFocus.dispose();
    _emergencyPhoneFocus.dispose();
    super.dispose();
  }

  void _initPatientData() {
    // Always fetch latest from SharedPreferences using the ID from args.
    // This ensures vitals updated in dashboard are visible in profile too.
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? targetId = (args is Patient) ? args.id : null;
    _loadPatientById(targetId);
  }

  Future<void> _loadPatientById(String? targetId) async {
    try {
      if (targetId == null) {
        final prefs = await SharedPreferences.getInstance();
        final patientsJson = prefs.getStringList('registered_patients') ?? [];
        if (patientsJson.isNotEmpty) {
          final lastMap = jsonDecode(patientsJson.last) as Map<String, dynamic>;
          targetId = lastMap['id'] as String?;
        }
      }

      if (targetId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final patient = await IdService.getPatientById(targetId);
      if (patient != null) {
        setState(() {
          _patient = patient;
          _phoneController.text = patient.phoneNumber;
          _emailController.text = patient.email;
          _addressController.text = patient.address;
          _emergencyNameController.text = patient.emergencyContactName;
          _emergencyPhoneController.text = patient.emergencyContactPhone;

          if (_relationships.contains(patient.emergencyContactRelation)) {
            _emergencyRelation = patient.emergencyContactRelation;
          } else if (patient.emergencyContactRelation.isNotEmpty) {
            _emergencyRelation = 'Other';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading patient: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_patient == null || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedData = {
      'phoneNumber': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelation': _emergencyRelation,
    };

    final updatedPatient = _patient!.copyWith(
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      emergencyContactRelation: _emergencyRelation,
    );

    try {
      await IdService.updatePatientProfile(_patient!.id, updatedData);
      
      setState(() {
        _patient = updatedPatient;
        _isSaving = false;
      });

      if (mounted) {
        _showSuccessSnackBar('Profile updated successfully!');
        Navigator.pop(context, updatedPatient);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to update profile. Please try again.');
    }
  }

  void _showErrorSnackBar(String msg) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_patient == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('Profile not found.')),
      );
    }

    final String initials = _patient!.fullName.isNotEmpty
        ? _patient!.fullName[0].toUpperCase()
        : 'P';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 26),
              tooltip: 'Save Profile',
              onPressed: _saveProfile,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar & Name Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: Border.all(
                            color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFF4F46E5).withOpacity(0.2),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)).withOpacity(0.15),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 16),
                      Text(
                        _patient!.fullName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient ID: ${_patient!.id}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // SECTION 1: Personal Clinical Record (Read-Only)
                _buildSectionTitle(isDark, 'Clinical Demographics (Read-only)', Icons.folder_shared_rounded),
                const SizedBox(height: 12),
                _buildClinicalReadOnlyCard(isDark),
                const SizedBox(height: 28),

                // SECTION 2: Contact Information (Editable)
                _buildSectionTitle(isDark, 'Contact Information', Icons.contact_mail_rounded),
                const SizedBox(height: 12),
                _buildContactEditFields(isDark),
                const SizedBox(height: 28),

                // SECTION 3: Emergency Contact (Editable)
                _buildSectionTitle(isDark, 'Emergency Contact Details', Icons.contact_phone_rounded),
                const SizedBox(height: 12),
                _buildEmergencyEditFields(isDark),
                const SizedBox(height: 36),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: _isSaving 
                        ? const Text('Saving Changes...') 
                        : const Text('Save Profile Updates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildClinicalReadOnlyCard(bool isDark) {
    final dob = _patient!.dateOfBirth;
    final formattedDOB = '${dob.day}/${dob.month}/${dob.year}';
    final regDate = _patient!.registrationDate;
    final formattedReg = '${regDate.day}/${regDate.month}/${regDate.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _buildReadOnlyRow('Gender', _patient!.gender),
          _buildReadOnlyRow('Date of Birth', '$formattedDOB (${_patient!.age} years)'),
          _buildReadOnlyRow('Blood Group', _patient!.bloodGroup),
          _buildReadOnlyRow('Height', '${_patient!.height} cm'),
          _buildReadOnlyRow('Weight', '${_patient!.weight} kg'),
          _buildReadOnlyRow('Registration Date', formattedReg),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildReadOnlyRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactEditFields(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFF1F5F9),
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
      child: Column(
        children: [
          _buildTextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FormEnterNavigation.focusNext(context, _emailFocus),
            label: 'Phone Number',
            hint: 'e.g. +91 98765 43210',
            icon: Icons.phone_rounded,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^[+0-9\s\-]*$')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              if (value.trim().length < 8) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FormEnterNavigation.focusNext(context, _addressFocus),
            label: 'Email Address',
            hint: 'e.g. patient@example.com',
            icon: Icons.email_rounded,
            isDark: isDark,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _addressController,
            focusNode: _addressFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FormEnterNavigation.focusNext(context, _emergencyNameFocus),
            label: 'Physical Address',
            hint: 'Street, City, State, ZIP',
            icon: Icons.home_rounded,
            isDark: isDark,
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Physical address is required';
              }
              return null;
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildEmergencyEditFields(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF818CF8).withOpacity(0.3) : const Color(0xFFF1F5F9),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _emergencyNameController,
            focusNode: _emergencyNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FormEnterNavigation.focusNext(context, _emergencyPhoneFocus),
            label: 'Emergency Contact Name',
            hint: 'Full Name of contact',
            icon: Icons.person_rounded,
            isDark: isDark,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Emergency contact name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _emergencyPhoneController,
            focusNode: _emergencyPhoneFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FormEnterNavigation.onFieldDone(
              context,
              onSubmit: () => _saveProfile(),
            ),
            label: 'Emergency Phone Number',
            hint: 'Phone number of contact',
            icon: Icons.phone_android_rounded,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^[+0-9\s\-]*$')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Emergency phone number is required';
              }
              if (value.trim().length < 8) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _emergencyRelation,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              labelText: 'Relationship to Patient',
              prefixIcon: Icon(
                Icons.people_alt_rounded,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                size: 20,
              ),
              labelStyle: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF4B6080) : const Color(0xFFCBD5E1),
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  width: 2.0,
                ),
              ),
            ),
            items: _relationships.map((relation) {
              return DropdownMenuItem<String>(
                value: relation,
                child: Text(relation),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _emergencyRelation = val;
                });
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: isDark ? const Color(0xFF818CF8) : Colors.grey.shade500,
          size: 20,
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF4B6080) : const Color(0xFFCBD5E1),
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 2.0,
          ),
        ),
      ),
    );
  }
}
