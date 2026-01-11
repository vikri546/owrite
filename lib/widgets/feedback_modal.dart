import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/feedback_service.dart';

/// Modal feedback yang wajib diisi user setelah 5 menit penggunaan app
class FeedbackModal extends StatefulWidget {
  const FeedbackModal({Key? key}) : super(key: key);

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackService = FeedbackService();
  
  // Controllers
  final _namaController = TextEditingController();
  final _peningkatanController = TextEditingController();
  final _fiturController = TextEditingController();
  final _deskripsiController = TextEditingController();
  
  // State
  String? _selectedProfesi;
  String? _selectedUmur;
  int _rating = 0;
  bool _isSubmitting = false;
  
  // Umur options (age ranges)
  static const List<String> _umurOptions = [
    'Di bawah 18 tahun',
    '18 - 24 tahun',
    '25 - 34 tahun',
    '35 - 44 tahun',
    '45 - 54 tahun',
    '55 tahun ke atas',
  ];
  
  // Profesi options
  static const List<String> _profesiOptions = [
    'Pelajar',
    'Mahasiswa',
    'Pekerja',
    'Wiraswasta',
    'Freelancer',
    'Ibu Rumah Tangga',
    'Lainnya',
  ];

  // Colors
  static const Color _accentColor = Color(0xFFCCFF00);
  static const Color _bgColor = Color(0xFF1A1A1A);
  static const Color _cardColor = Color(0xFF2A2A2A);

  @override
  void dispose() {
    _namaController.dispose();
    _peningkatanController.dispose();
    _fiturController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan berikan rating untuk aplikasi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _feedbackService.sendFeedback(
      nama: _namaController.text.trim(),
      umur: _selectedUmur ?? 'Tidak diisi',
      profesi: _selectedProfesi ?? 'Tidak diisi',
      rating: _rating,
      peningkatan: _peningkatanController.text.trim(),
      fiturDiinginkan: _fiturController.text.trim(),
      deskripsiIdeal: _deskripsiController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      // Show thank you message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _accentColor, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Terima Kasih!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Feedback Anda sangat berharga untuk pengembangan aplikasi ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close thank you dialog
                  Navigator.of(context).pop(); // Close feedback modal
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Lanjutkan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Dialog(
        backgroundColor: _bgColor,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bantu Kami Berkembang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Bagikan pengalaman Anda',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama
                        _buildLabel('Nama'),
                        _buildTextField(
                          controller: _namaController,
                          hint: 'Masukkan nama Anda',
                          validator: (v) => v?.isEmpty == true ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // Umur (Dropdown)
                        _buildLabel('Umur'),
                        _buildUmurDropdown(),
                        const SizedBox(height: 12),
                        
                        // Profesi (Dropdown)
                        _buildLabel('Profesi'),
                        _buildDropdown(),
                        const SizedBox(height: 16),
                        
                        // Rating
                        _buildLabel('Rating Aplikasi'),
                        _buildRatingStars(),
                        const SizedBox(height: 16),
                        
                        // Peningkatan
                        _buildLabel('Apa yang perlu ditingkatkan?'),
                        _buildTextField(
                          controller: _peningkatanController,
                          hint: 'Contoh: Kecepatan loading, UI, dll',
                          maxLines: 2,
                          validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // Fitur
                        _buildLabel('Fitur apa yang Anda inginkan?'),
                        _buildTextField(
                          controller: _fiturController,
                          hint: 'Contoh: Dark mode, Offline reading, dll',
                          maxLines: 2,
                          validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // Deskripsi ideal
                        _buildLabel('Deskripsikan aplikasi berita ideal Anda'),
                        _buildTextField(
                          controller: _deskripsiController,
                          hint: 'Maksimal 500 karakter...',
                          maxLines: 4,
                          maxLength: 500,
                          validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Submit Button
              Container(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Kirim Feedback',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: _cardColor,
        counterStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentColor, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }

  Widget _buildUmurDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUmur,
      hint: Text('Pilih rentang umur', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      dropdownColor: _cardColor,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v == null ? 'Umur wajib dipilih' : null,
      items: _umurOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) => setState(() => _selectedUmur = v),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedProfesi,
      hint: Text('Pilih profesi', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      dropdownColor: _cardColor,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v == null ? 'Profesi wajib dipilih' : null,
      items: _profesiOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
      onChanged: (v) => setState(() => _selectedProfesi = v),
    );
  }

  Widget _buildRatingStars() {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => setState(() => _rating = starIndex),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _rating >= starIndex ? Icons.star : Icons.star_border,
              color: _rating >= starIndex ? _accentColor : Colors.grey[600],
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}

/// Show feedback modal with fade animation (cannot be dismissed)
Future<void> showFeedbackModal(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false, // Cannot close by tapping outside
    barrierColor: Colors.black87,
    barrierLabel: 'Feedback',
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const FeedbackModal();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
