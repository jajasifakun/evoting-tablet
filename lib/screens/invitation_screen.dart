import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/database_helper.dart';
import '../services/thermal_printer_service.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  final GlobalKey _cardKey = GlobalKey();
  List<Map<String, dynamic>> _voterCards = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadVoterTokens();
  }

  Future<void> _loadVoterTokens() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getTokensWithVoters();
    setState(() {
      _voterCards = list;
      _isLoading = false;
    });
  }

  Future<void> _downloadCurrentPdf() async {
    if (_voterCards.isEmpty) return;
    setState(() => _isDownloading = true);

    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Komponen kartu belum siap");

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Gagal menghasilkan gambar kartu");
      final bytes = byteData.buffer.asUint8List();

      final current = _voterCards[_selectedIndex];
      final voterName = current['voter_name'] ?? 'Pemilih';
      final cleanName = voterName.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'Surat_Undangan_C6_${_selectedIndex + 1}_$cleanName.pdf';

      final res = await ThermalPrinterService.instance.createSinglePdf(fileName, bytes);

      if (!mounted) return;
      setState(() => _isDownloading = false);

      final bool isSuccess = res['success'] == true;
      final String filePath = res['filePath']?.toString() ?? '';
      final String displayPath = res['displayPath']?.toString() ?? 'Folder Download / Dokumen';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(isSuccess ? 'Berhasil Diunduh (PDF)!' : 'Gagal Mengunduh', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuccess
                    ? 'Surat Undangan C-6 untuk pemilih $voterName berhasil disimpan dalam format dokumen PDF resmi siap cetak.'
                    : 'Terjadi kendala saat menyimpan dokumen PDF: ${res['error'] ?? 'Gagal membuat file'}',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('📁 Lokasi: $displayPath\n📄 Berkas: $fileName', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ],
          ),
          actions: [
            if (isSuccess && filePath.isNotEmpty) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Buka PDF'),
                onPressed: () {
                  ThermalPrinterService.instance.openPdf(filePath);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Bagikan'),
                onPressed: () {
                  ThermalPrinterService.instance.sharePdf(filePath);
                },
              ),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mengunduh: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadAllPdf() async {
    if (_voterCards.isEmpty) return;
    setState(() => _isDownloading = true);

    try {
      const fileName = 'Surat_Undangan_C6_Semua_10_Pemilih.pdf';
      final started = await ThermalPrinterService.instance.startMultiPagePdf(fileName);
      if (!started) throw Exception("Gagal menginisialisasi dokumen PDF multi-halaman");

      int pageCount = 0;
      for (int i = 0; i < _voterCards.length; i++) {
        setState(() => _selectedIndex = i);
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 120));

        final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.2);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            final ok = await ThermalPrinterService.instance.addPageToPdf(bytes);
            if (ok) pageCount++;
          }
        }
      }

      final res = await ThermalPrinterService.instance.finishMultiPagePdf();

      if (!mounted) return;
      setState(() => _isDownloading = false);

      final bool isSuccess = res['success'] == true;
      final String filePath = res['filePath']?.toString() ?? '';
      final String displayPath = res['displayPath']?.toString() ?? 'Folder Download / Dokumen';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(isSuccess ? 'Unduh 10 Surat Selesai (PDF)!' : 'Gagal Mengunduh', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuccess
                    ? 'Sebanyak $pageCount halaman Surat Undangan (Model C-6 KWK) telah digabungkan menjadi 1 file PDF resmi siap cetak.'
                    : 'Terjadi kendala saat menyimpan dokumen PDF: ${res['error'] ?? 'Gagal membuat file'}',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('📁 Lokasi: $displayPath\n📄 Berkas: $fileName ($pageCount Halaman)', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ],
          ),
          actions: [
            if (isSuccess && filePath.isNotEmpty) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Buka Dokumen PDF'),
                onPressed: () {
                  ThermalPrinterService.instance.openPdf(filePath);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Bagikan'),
                onPressed: () {
                  ThermalPrinterService.instance.sharePdf(filePath);
                },
              ),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mengunduh berkas: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        title: const Text(
          'Surat Undangan Barcode (Model C-6)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Surat Undangan Ini (PDF)',
            onPressed: _isDownloading ? null : _downloadCurrentPdf,
          ),
          PopupMenuButton<String>(
            tooltip: 'Pilihan Unduh Dokumen PDF',
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'single') _downloadCurrentPdf();
              if (val == 'all') _downloadAllPdf();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'single',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.indigo, size: 20),
                    SizedBox(width: 8),
                    Text('Download Surat Ini (PDF)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.file_copy, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Download Semua 10 Surat (PDF)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _voterCards.isEmpty
              ? const Center(child: Text('Tidak ada data DPT.'))
              : Row(
                  children: [
                    // Sisi Kiri: Daftar 10 Pemilih
                    Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.indigo.shade50,
                            child: Row(
                              children: [
                                Icon(Icons.people, color: Colors.indigo.shade800, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pilih Pemilih (${_voterCards.length} DPT)',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _voterCards.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final item = _voterCards[idx];
                                final isSelected = idx == _selectedIndex;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.indigo.shade100,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isSelected ? Colors.indigo : Colors.grey.shade300,
                                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(
                                    item['voter_name'] ?? 'Pemilih Lepas',
                                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    item['token_code'] ?? '',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                                  ),
                                  onTap: () => setState(() => _selectedIndex = idx),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sisi Kanan: Lembar Preview Surat Undangan Resmi
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              children: [
                                // Tombol Download Cepat
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Download Surat Ini (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: _isDownloading ? null : _downloadCurrentPdf,
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.indigo.shade800,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.file_copy, size: 18),
                                      label: const Text('Download Semua 10 Surat (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: _isDownloading ? null : _downloadAllPdf,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Kartu Undangan yang Ditangkap untuk Download
                                RepaintBoundary(
                                  key: _cardKey,
                                  child: _buildInvitationCard(_voterCards[_selectedIndex]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> item) {
    final voterName = item['voter_name'] ?? 'SULAEMAN';
    final nik = item['voter_nik'] ?? '3213051001900001';
    final tokenCode = item['token_code'] ?? 'KM2026-TEST-VOTE01';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black87, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kop Surat
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/pilkades-logo.png', width: 50, height: 50, errorBuilder: (_, __, ___) => const Icon(Icons.how_to_vote, size: 45, color: Colors.indigo)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    const Text('PANITIA PEMILIHAN KEPALA DESA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                    Text('DESA KARANG MUKTI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo.shade800)),
                    const Text('Kecamatan Cipeundeuy • Kabupaten Subang', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: const Text('MODEL C-6 KWK PILKADES 2026', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 50),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(thickness: 1.5, color: Colors.black),
          const SizedBox(height: 6),

          const Center(
            child: Text(
              'SURAT PEMBERITAHUAN PEMUNGUTAN SUARA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
            ),
          ),
          const Center(
            child: Text(
              'Bawalah lembar ini ke TPS 01 untuk dipindai pada kamera bilik suara',
              style: TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),

          // Baris Konten: QR Code di KIRI ATAS & Data Pemilih di KANAN
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri: Barcode QR & Box Panduan Jempol (SEBELAH KIRI ATAS)
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Kotak QR Code
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: tokenCode,
                            version: QrVersions.auto,
                            size: 115.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tokenCode,
                            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: Colors.indigo.shade700),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // KOTAK VISUAL KHUSUS: PANDUAN POSISI JEMPOL
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade700, width: 2, strokeAlign: BorderSide.strokeAlignInside),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.thumb_up_alt, size: 16, color: Colors.indigo),
                              const SizedBox(width: 4),
                              Text(
                                'AREA JEMPOL',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.indigo.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.shade300, borderRadius: BorderRadius.circular(4)),
                            child: const Text('PEGANG DI SINI 👍', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.5, color: Colors.black87)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pegang kertas di sisi kanan agar QR Code di kiri atas bebas di-scan kamera.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8.5, color: Color(0xFF1E1B4B), height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Kolom Kanan: Identitas DPT Pemilih
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Nama Pemilih', voterName, isBold: true),
                    _buildInfoRow('NIK', nik, isMonospace: true),
                    _buildInfoRow('Jenis Kelamin', 'Laki-laki / Perempuan'),
                    _buildInfoRow('RT / RW', 'RT 001 / RW 001'),
                    _buildInfoRow('Lokasi TPS', 'TPS 01 Desa Karang Mukti', isPrimary: true),
                    _buildInfoRow('Status Kupon', 'Kupon Suara Sah 1 Kali'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Petunjuk Bilik Suara
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Petunjuk Singkat di Bilik Suara:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                SizedBox(height: 4),
                Text('1. Pegang lembaran pada AREA JEMPOL di bagian bawah.', style: TextStyle(fontSize: 10)),
                Text('2. Arahkan QR Code ke kamera tablet hingga terdengar bunyi verifikasi.', style: TextStyle(fontSize: 10)),
                Text('3. Pilih calon di layar sentuh tablet, konfirmasi, dan ambil struk fisik untuk dimasukkan ke KOTAK SUARA FISIK.', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tanda Tangan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const Text('Pemilih', style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 35),
                  Text('($voterName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
              Column(
                children: [
                  const Text('Karang Mukti, 2026\nKetua KPPS 1', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 25),
                  const Text('( KASDA, S.T., M.T. )', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isMonospace = false, bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isPrimary ? Colors.indigo.shade800 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
