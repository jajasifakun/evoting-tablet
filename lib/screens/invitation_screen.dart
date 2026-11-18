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
                                  child: _buildInvitationCard(_voterCards[_selectedIndex], _selectedIndex),
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

  Widget _buildInvitationCard(Map<String, dynamic> item, int index) {
    final voterName = (item['voter_name'] ?? item['name'] ?? 'SAMSUL BAHRIYANTO').toString().toUpperCase();
    final nik = (item['voter_nik'] ?? item['nik'] ?? '9909052107890001').toString();
    final tokenCode = item['token_code'] ?? 'KM2026-TEST-VOTE01';
    final dptNo = item['dpt_no'] ?? item['id'] ?? (index + 1);

    // Dynamic TPS & Bilik Suara, Alamat TPS Tetap (Ciomas RT 09 RW 05)
    final rawTps = item['tps_no'] ?? item['tps'] ?? '1';
    final formattedTps = rawTps.toString().toUpperCase().contains('TPS') ? rawTps.toString() : 'TPS $rawTps';

    const formattedAddress = 'Ciomas RT 09 RW 05';

    final rawBilik = item['bilik_no'] ?? item['bilik'] ?? '1';
    final formattedBilik = rawBilik.toString().toLowerCase().contains('bilik')
        ? rawBilik.toString()
        : 'Bilik Suara Nomor $rawBilik';

    final now = DateTime.now();
    final printTime = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KOP SURAT 3 KOLOM DENGAN GARIS PEMISAH VERTIKAL HITAM
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kolom Kiri: Logo Pilkades Karangmukti
                Container(
                  width: 90,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Image.asset(
                    'assets/images/pilkades-logo.png',
                    width: 82,
                    height: 82,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.how_to_vote, size: 60, color: Colors.indigo),
                  ),
                ),

                // Garis Vertikal Pemisah 1
                Container(
                  width: 1.8,
                  color: Colors.black,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom Tengah: Judul Resmi Surat Undangan
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SURAT UNDANGAN',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PEMUNGUTAN SUARA',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'KEPADA PEMILIH',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),

                // Garis Vertikal Pemisah 2
                Container(
                  width: 1.8,
                  color: Colors.black,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Kolom Kanan: No Urut DPT
                Container(
                  width: 85,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No Urut DPT',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      Text(
                        '$dptNo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black, height: 1.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Garis Horizontal Pemisah Header
          Container(
            height: 2.0,
            color: Colors.black,
            margin: const EdgeInsets.only(top: 10, bottom: 14),
          ),

          // 2. BARIS QR CODE (KIRI) & KOTAK INSTRUKSI (KANAN)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // QR Code di Kiri (Besar, tajam, jelas)
              QrImageView(
                data: tokenCode,
                version: QrVersions.auto,
                size: 118.0,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),

              const SizedBox(width: 14),

              // Dua Kotak Berbingkai di Kanan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    // Kotak 1: Merah (SURAT UNDANGAN INI BERSIFAT RAHASIA)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE53935), width: 1.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Center(
                        child: Text(
                          'SURAT UNDANGAN INI BERSIFAT RAHASIA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Kotak 2: Border Hitam (Tunjukan QRcode berikut saat akan memilih)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Center(
                        child: Text(
                          'Tunjukan QRcode berikut saat akan memilih',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. PARAGRAF UNDANGAN RESMI
          Text.rich(
            TextSpan(
              text: 'Bersama ini diberitahukan bahwa Panitia Pemilihan mengundang Saudara/i\n',
              style: const TextStyle(fontSize: 11, color: Colors.black, height: 1.35),
              children: [
                TextSpan(
                  text: '$voterName ',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const TextSpan(text: 'NIK '),
                TextSpan(
                  text: '$nik ',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const TextSpan(text: 'untuk memberikan suara\npada pemilihan: '),
                const TextSpan(
                  text: 'PEMILIHAN KEPALA DESA KARANGMUKTI ',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const TextSpan(text: 'yang akan\ndilaksanakan pada:'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. TABEL JADWAL & LOKASI PEMILIHAN
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Column(
              children: [
                _buildScheduleRow('Hari/Tanggal', 'Minggu, 06 Desember 2026', isBold: true),
                _buildScheduleRow('Pukul', '07:00 s/d 14:00 WIB'),
                _buildScheduleRow('Nomor TPS', formattedTps),
                _buildScheduleRow('Alamat TPS', formattedAddress),
                _buildScheduleRow('Nomor Bilik Suara', formattedBilik),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 5. CATATAN KETENTUAN
          const Text.rich(
            TextSpan(
              text: 'Catatan : ',
              style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold, height: 1.35),
              children: [
                TextSpan(
                  text:
                      'Surat Undangan ini beserta KTP Elektronik harus dibawa pada saat pencoblosan dan tidak boleh diwakilkan. Surat Undangan ini tidak boleh disebarluaskan, duplikasi atau diperlihatkan kepada pihak yang tidak berkepentingan.',
                  style: TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
            textAlign: TextAlign.justify,
          ),

          const SizedBox(height: 16),

          // 6. TANDA TANGAN (Kiri: Penerima, Kanan: Panitia Pemilihan Subang)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri: Yang Menerima
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('..................., ............ 2026', style: TextStyle(fontSize: 10.5, color: Colors.black)),
                    const SizedBox(height: 2),
                    const Text('Yang Menerima,', style: TextStyle(fontSize: 10.5, color: Colors.black)),
                    const SizedBox(height: 42),
                    Text(
                      voterName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ],
                ),
              ),

              // Kolom Kanan: Panitia Pemilihan Ketua Subang
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subang, 10 November 2026', style: TextStyle(fontSize: 10.5, color: Colors.black)),
                    SizedBox(height: 2),
                    Text('PANITIA PEMILIHAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                    Text('Ketua,', style: TextStyle(fontSize: 10.5, color: Colors.black)),
                    SizedBox(height: 38),
                    Text('Kasda, S.T., M.T', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 7. BAGIAN BAWAH: NAMA PEMILIH, KOTAK PANDUAN POSISI TANGAN, GAMBAR JEMPOL, TANGGAL CETAK
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Kolom Kiri: Nama Pemilih + Kotak Instruksi Letak Tangan
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    voterName,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Letakan posisi tangan\nditengah-tengah ujung\nbawah persis seperti\npada gambar untuk\nmemudahkan proses\nscan QRcode',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, height: 1.25, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Gambar Ilustrasi Jempol & Sensor Scan (hand_guide.png)
              Image.asset(
                'assets/images/hand_guide.png',
                height: 78,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.fingerprint, size: 60, color: Colors.red),
              ),

              const Spacer(),

              // Tanggal & Waktu Cetak (Italic)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Tgl cetak: $printTime',
                  style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(label, style: const TextStyle(fontSize: 10.8, color: Colors.black, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(
            width: 14,
            child: Text(':', style: TextStyle(fontSize: 10.8, color: Colors.black, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.8,
                color: Colors.black,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
