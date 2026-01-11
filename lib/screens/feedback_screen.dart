import 'package:flutter/material.dart';
import '../services/feedback_service.dart';

/// Full-page Feedback Screen untuk mengirim/edit feedback
class FeedbackScreen extends StatefulWidget {
  final bool isDark;
  const FeedbackScreen({Key? key, this.isDark = false}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
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
  bool _hasProfile = false;
  bool _canSubmit = true;
  
  // Umur options
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

  static const Color _accentColor = Color(0xFFCCFF00);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _feedbackService.getSavedUserData();
    final hasProfile = await _feedbackService.hasUserProfile();
    final canSubmit = await _feedbackService.canSubmitFeedback();
    
    if (mounted) {
      setState(() {
        _hasProfile = hasProfile;
        _canSubmit = canSubmit;
        if (hasProfile) {
          _namaController.text = userData['nama'] ?? '';
          _selectedUmur = userData['umur'];
          _selectedProfesi = userData['profesi'];
        }
      });
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _peningkatanController.dispose();
    _fiturController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  // Count words in text
  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // Validate max words
  String? _validateMaxWords(String? value, int maxWords) {
    if (value == null || value.isEmpty) return 'Wajib diisi';
    if (_countWords(value) > maxWords) return 'Maksimal $maxWords kata';
    return null;
  }

  Future<void> _submitFeedback() async {
    if (!_canSubmit) return;
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

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.black),
                SizedBox(width: 8),
                Text('Terima kasih! Feedback berhasil dikirim.', style: TextStyle(color: Colors.black)),
              ],
            ),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batas feedback mingguan tercapai (3x). Coba lagi minggu depan.'),
            backgroundColor: Colors.red,
          ),
        );
        // Reload to update canSubmit state
        _loadUserData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black;
    final disabledColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    
    // All fields disabled when limit reached
    final bool isBlocked = !_canSubmit;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Kirim Feedback', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Limit warning - only show when blocked
              if (isBlocked) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Batas Tercapai', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Anda sudah mengirim 3 feedback minggu ini. Silakan coba lagi minggu depan.', 
                                 style: TextStyle(color: disabledColor, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Nama - show as text if has profile, otherwise editable
              _buildLabel('Nama', textColor),
              if (_hasProfile)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_namaController.text, style: TextStyle(color: textColor, fontSize: 14)),
                )
              else
                TextFormField(
                  controller: _namaController,
                  enabled: !isBlocked,
                  style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                  decoration: _inputDecoration('Masukkan nama Anda', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                  validator: (v) => v?.isEmpty == true ? 'Nama wajib diisi' : null,
                ),
              const SizedBox(height: 16),

              // Umur
              _buildLabel('Umur', textColor),
              if (_hasProfile)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_selectedUmur ?? '-', style: TextStyle(color: textColor, fontSize: 14)),
                )
              else
                IgnorePointer(
                  ignoring: isBlocked,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUmur,
                    hint: Text('Pilih rentang umur', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    dropdownColor: cardColor,
                    style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                    decoration: _inputDecoration('', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                    validator: (v) => v == null ? 'Umur wajib dipilih' : null,
                    items: _umurOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUmur = v),
                  ),
                ),
              const SizedBox(height: 16),

              // Profesi
              _buildLabel('Profesi', textColor),
              if (_hasProfile)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_selectedProfesi ?? '-', style: TextStyle(color: textColor, fontSize: 14)),
                )
              else
                IgnorePointer(
                  ignoring: isBlocked,
                  child: DropdownButtonFormField<String>(
                    value: _selectedProfesi,
                    hint: Text('Pilih profesi', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    dropdownColor: cardColor,
                    style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                    decoration: _inputDecoration('', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                    validator: (v) => v == null ? 'Profesi wajib dipilih' : null,
                    items: _profesiOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _selectedProfesi = v),
                  ),
                ),
              const SizedBox(height: 20),

              // Rating
              _buildLabel('Rating Aplikasi', textColor),
              IgnorePointer(
                ignoring: isBlocked,
                child: Opacity(
                  opacity: isBlocked ? 0.5 : 1.0,
                  child: _buildRatingStars(),
                ),
              ),
              const SizedBox(height: 20),

              // Peningkatan (max 100 words)
              _buildLabel('Apa yang perlu ditingkatkan? (maks 100 kata)', textColor),
              TextFormField(
                controller: _peningkatanController,
                maxLines: 2,
                enabled: !isBlocked,
                style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                decoration: _inputDecoration('Contoh: Kecepatan loading, UI, dll', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                validator: (v) => _validateMaxWords(v, 100),
              ),
              const SizedBox(height: 16),

              // Fitur (max 100 words)
              _buildLabel('Fitur apa yang Anda inginkan? (maks 100 kata)', textColor),
              TextFormField(
                controller: _fiturController,
                maxLines: 2,
                enabled: !isBlocked,
                style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                decoration: _inputDecoration('Contoh: Offline reading, dll', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                validator: (v) => _validateMaxWords(v, 100),
              ),
              const SizedBox(height: 16),

              // Deskripsi (max 500 chars)
              _buildLabel('Deskripsikan aplikasi berita ideal Anda', textColor),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                maxLength: 500,
                enabled: !isBlocked,
                style: TextStyle(color: isBlocked ? disabledColor : textColor, fontSize: 14),
                decoration: _inputDecoration('Maksimal 500 karakter...', isDark, isBlocked ? disabledColor.withOpacity(0.3) : cardColor),
                validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isBlocked || _isSubmitting) ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.grey : _accentColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(isBlocked ? 'Tunggu Minggu Depan' : 'Kirim Feedback', 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark, Color fillColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500], fontSize: 13),
      filled: true,
      fillColor: fillColor,
      counterStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentColor, width: 1)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildRatingStars() {
    return Row(
      children: List.generate(5, (i) {
        final idx = i + 1;
        return GestureDetector(
          onTap: () => setState(() => _rating = idx),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(_rating >= idx ? Icons.star : Icons.star_border, 
                       color: _rating >= idx ? _accentColor : Colors.grey[600], size: 36),
          ),
        );
      }),
    );
  }
}