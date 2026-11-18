import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/database_helper.dart';
import '../services/thermal_printer_service.dart';
import 'invitation_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<VoteResult> _results = [];
  int _totalVoters = 0;
  int _votedCount = 0;
  List<Voter> _votersList = [];
  List<Map<String, dynamic>> _tokensList = [];
  List<Map<String, String>> _pairedPrinters = [];
  List<Map<String, dynamic>> _usbPrinters = [];
  int _printerModeIndex = 0; // 0 = Bluetooth, 1 = USB OTG
  bool _isConnectingPrinter = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
    _loadPairedPrinters();
    _loadUsbPrinters();
    ThermalPrinterService.instance.getConnectionStatus().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPairedPrinters() async {
    final list = await ThermalPrinterService.instance.getPairedDevices();
    if (mounted) {
      setState(() => _pairedPrinters = list);
    }
  }

  Future<void> _loadUsbPrinters() async {
    final list = await ThermalPrinterService.instance.getUsbDevices();
    if (mounted) {
      setState(() => _usbPrinters = list);
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final results = await DatabaseHelper.instance.getVoteResults();
    final total = await DatabaseHelper.instance.getTotalVotersCount();
    final voted = await DatabaseHelper.instance.getVotedVotersCount();
    final voters = await DatabaseHelper.instance.getAllVoters();
    final tokens = await DatabaseHelper.instance.getTokensWithVoters();

    setState(() {
      _results = results;
      _totalVoters = total;
      _votedCount = voted;
      _votersList = voters;
      _tokensList = tokens;
      _isLoading = false;
    });
  }

  Future<void> _handleResetVotersOnly() async {
    final confirm = await _showConfirmDialog(
      title: 'Reset Status Pemilih & QR Saja',
      message: 'Seluruh DPT akan dikembalikan menjadi "Belum Memilih" dan seluruh QR Code menjadi "Unused" agar bisa dicoblos ulang pada simulasi tanpa menghapus perolehan suara.',
    );
    if (confirm == true) {
      await DatabaseHelper.instance.resetAllVotersAndTokensOnly();
      await _loadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status pemilih & QR Code berhasil direset!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _handleResetTotalSimulation() async {
    final confirm = await _showConfirmDialog(
      title: '⚠️ RESET TOTAL SELURUH SIMULASI',
      message: 'PERINGATAN: Seluruh suara hasil simulasi akan dihapus kembali ke 0 suara, dan seluruh ${_votersList.isNotEmpty ? _votersList.length : 20} DPT serta QR Code diaktifkan kembali seperti TPS baru dibuka. Lanjutkan?',
      isDanger: true,
    );
    if (confirm == true) {
      await DatabaseHelper.instance.resetFullSimulation();
      await _loadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulasi berhasil direset total (0 suara)!'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<bool?> _showConfirmDialog({required String title, required String message, bool isDanger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDanger ? Colors.red : Colors.black87)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? Colors.red : Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        title: const Text('Panel Administrator & KPPS TPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            const Tab(icon: Icon(Icons.bar_chart), text: 'Rekap Suara'),
            Tab(icon: const Icon(Icons.people), text: 'Daftar DPT (${_votersList.isNotEmpty ? _votersList.length : 20})'),
            const Tab(icon: Icon(Icons.qr_code_2), text: 'Token QR'),
            const Tab(icon: Icon(Icons.mail_outline), text: 'Undangan & Barcode'),
            const Tab(icon: Icon(Icons.print), text: 'Printer Thermal'),
            const Tab(icon: Icon(Icons.settings_backup_restore), text: 'Reset Simulasi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecapTab(),
                _buildVotersTab(),
                _buildTokensTab(),
                _buildInvitationTab(),
                _buildThermalPrinterTab(),
                _buildResetTab(),
              ],
            ),
    );
  }

  // --- TAB 1: REKAPITULASI SUARA ---
  Widget _buildRecapTab() {
    final totalVotes = _results.fold<int>(0, (sum, item) => sum + item.count);
    final participation = _totalVoters > 0 ? (_votedCount / _totalVoters) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Bar Cards
          Row(
            children: [
              _buildStatCard('Total DPT', '$_totalVoters', Colors.blue, Icons.group),
              const SizedBox(width: 12),
              _buildStatCard('Suara Masuk', '$totalVotes', Colors.green, Icons.how_to_vote),
              const SizedBox(width: 12),
              _buildStatCard('Partisipasi', '${participation.toStringAsFixed(1)}%', Colors.purple, Icons.pie_chart),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'HASIL PEROLEHAN SUARA KANDIDAT',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          // Hasil Calon A & Calon B
          ..._results.map((res) {
            final c = res.candidate;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(c.photoAsset, width: 65, height: 80, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calon ${c.letter} - ${c.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: res.percentage / 100,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${res.count} Suara', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo)),
                            Text('${res.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.amber.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Berita Acara disahkan oleh Ketua KPPS 1: Kasda, S.T.,M.T\nStatus Sistem: Offline Mandiri Tablet',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: DAFTAR PEMILIH (DPT) ---
  Widget _buildVotersTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _votersList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final v = _votersList[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: v.hasVoted ? Colors.green.shade100 : Colors.amber.shade100,
                child: Icon(
                  v.hasVoted ? Icons.check : Icons.person,
                  color: v.hasVoted ? Colors.green.shade800 : Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('NIK: ${v.nik} • RT ${v.rt}/RW ${v.rw}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (v.hasVoted) ...[
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.amber),
                  tooltip: 'Reset Pemilih Ini',
                  onPressed: () async {
                    await DatabaseHelper.instance.resetIndividualVoter(v.id);
                    await _loadAllData();
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('Sudah Memilih', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('Belum Memilih', style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: TOKEN QR ---
  Widget _buildTokensTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tokensList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final t = _tokensList[idx];
        final isUsed = t['status'] == 'used';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code, color: Colors.indigo, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['token_code'], style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 14, color: Colors.indigo)),
                    Text('Pemilik: ${t['voter_name'] ?? "Lepas"} (${t['voter_nik'] ?? "-"})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (isUsed) ...[
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.amber),
                  tooltip: 'Reset Token Ini',
                  onPressed: () async {
                    await DatabaseHelper.instance.resetIndividualToken(t['token_code']);
                    await _loadAllData();
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('Digunakan', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('Belum Dipakai', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4: RESET SIMULASI ---
  Widget _buildResetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KONTROL RESET SIMULASI PEMILIHAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Gunakan fitur ini selama masa uji coba agar kupon QR Code dan nama pemilih dapat dicoblos kembali kapan saja.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Card Opsi 1
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    const Text('1. Reset Status Pemilih & Token Saja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mengembalikan status ${_votersList.isNotEmpty ? _votersList.length : 20} DPT menjadi "Belum Memilih" dan seluruh QR Code menjadi "Unused". Suara pemilih sebelumnya tetap tersimpan.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Pemilih & QR Saja', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _handleResetVotersOnly,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card Opsi 2
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('2. Reset Total Simulasi (0 Suara)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mengosongkan kotak suara kembali ke 0 suara, menghapus seluruh rekaman coblosan simulasi, dan mengaktifkan kembali seluruh DPT serta QR Code.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Bersih Total (0 Suara)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _handleResetTotalSimulation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: SURAT UNDANGAN & BARCODE DENGAN PANDUAN JEMPOL ---
  Widget _buildInvitationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.mark_email_read, color: Colors.indigo.shade800, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Surat Undangan Pemilih (Model C-6 KWK)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo.shade900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dilengkapi Barcode otorisasi dan PANDUAN POSISI JEMPOL agar pemilih memegang kartu di tempat yang tepat sehingga scan kamera bilik berlangsung cepat.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Aksi Undangan
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.print),
                    label: Text(
                      'BUKA & CETAK ${_votersList.isNotEmpty ? _votersList.length : 20} UNDANGAN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InvitationScreen()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text(
                      'DOWNLOAD SURAT UNDANGAN (PDF)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InvitationScreen()),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'DAFTAR KARTU UNDANGAN PEMILIH (${_votersList.isNotEmpty ? _votersList.length : 20} DPT):',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tokensList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final t = _tokensList[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      foregroundColor: Colors.indigo.shade900,
                      child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['voter_name'] ?? 'Pemilih Lepas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('NIK: ${t['voter_nik'] ?? "-"} • Token: ${t['token_code']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo.shade700,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Lihat C-6', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InvitationScreen()),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 5: PENGATURAN PRINTER THERMAL KOTAK SUARA (KABEL USB + BLUETOOTH) ---
  Widget _buildThermalPrinterTab() {
    final printer = ThermalPrinterService.instance;
    final isConnected = printer.connectedPrinterName != null;
    final isUsb = printer.connectionType == 'USB';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Status Koneksi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isConnected ? Colors.green.shade400 : Colors.amber.shade400, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? (isUsb ? Icons.usb : Icons.print) : Icons.print_disabled,
                  color: isConnected ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isConnected
                                  ? 'Terhubung: ${printer.connectedPrinterName}'
                                  : 'Printer Thermal Belum Terhubung',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: isConnected ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isUsb ? Colors.teal.shade700 : Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUsb ? 'KABEL USB' : 'BLUETOOTH',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                          ? 'Printer siap mencetak bukti struk fisik ke dalam kotak suara saat pemilih mencoblos.'
                          : 'Hubungkan printer kasir thermal kecil (58mm/80mm) menggunakan Kabel USB (OTG) atau Bluetooth.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Switch Otomatis Cetak & Tombol Auto-Connect
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cetak Otomatis Struk ke Kotak Suara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      SizedBox(height: 2),
                      Text('Struk fisik otomatis keluar saat pemilih memilih calon', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: printer.autoPrintEnabled,
                  activeColor: Colors.green.shade700,
                  onChanged: (val) {
                    setState(() => printer.autoPrintEnabled = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tombol Uji Cetak & Hubungkan Otomatis
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('Auto-Connect Printer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mencari printer kabel USB & Bluetooth...'), duration: Duration(seconds: 1)),
                    );
                    final ok = await printer.autoConnect();
                    await _loadPairedPrinters();
                    await _loadUsbPrinters();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Berhasil terhubung ke ${printer.connectedPrinterName}!' : 'Tidak ditemukan printer aktif. Pastikan kabel OTG / Bluetooth aktif.'),
                        backgroundColor: ok ? Colors.green : Colors.orange,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Test Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () async {
                    final ok = await printer.printTestReceipt();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Perintah cetak terkirim ke printer thermal!' : 'Gagal mencetak. Hubungkan via Kabel USB atau Bluetooth terlebih dahulu.'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // TAB PILIHAN METODE KONEKSI (BLUETOOTH vs KABEL USB)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _printerModeIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _printerModeIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _printerModeIndex == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth, size: 18, color: _printerModeIndex == 0 ? Colors.blue.shade700 : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Koneksi Bluetooth',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _printerModeIndex == 0 ? Colors.blue.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() => _printerModeIndex = 1);
                      _loadUsbPrinters();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _printerModeIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _printerModeIndex == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.usb, size: 18, color: _printerModeIndex == 1 ? Colors.teal.shade700 : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Koneksi Kabel USB (OTG)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _printerModeIndex == 1 ? Colors.teal.shade800 : Colors.grey.shade700,
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

          const SizedBox(height: 16),

          // ISI METODE 1: KONEKSI BLUETOOTH
          if (_printerModeIndex == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DAFTAR PRINTER BLUETOOTH (PAIRED):',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                  onPressed: _loadPairedPrinters,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_pairedPrinters.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'Belum ada printer Bluetooth terdeteksi.\n1. Nyalakan printer thermal kecil Anda.\n2. Buka Pengaturan Bluetooth tablet/HP dan pasangkan (pair) printer.\n3. Tekan Refresh di atas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pairedPrinters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final p = _pairedPrinters[idx];
                  final name = p['name'] ?? 'Printer Thermal';
                  final addr = p['address'] ?? '';
                  final isConn = printer.connectedPrinterAddress == addr && printer.connectionType == 'BLUETOOTH';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isConn ? Colors.green : Colors.grey.shade200, width: isConn ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth, color: isConn ? Colors.green : Colors.blue.shade700),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              Text(addr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (isConn)
                          OutlinedButton(
                            onPressed: () async {
                              await printer.disconnect();
                              setState(() {});
                            },
                            child: const Text('Putuskan'),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isConnectingPrinter
                                ? null
                                : () async {
                                    setState(() => _isConnectingPrinter = true);
                                    final ok = await printer.connect(addr, name);
                                    setState(() => _isConnectingPrinter = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Berhasil terhubung ke $name via Bluetooth!' : 'Gagal menghubungkan ke $name.'),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                            child: const Text('Hubungkan'),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],

          // ISI METODE 2: KONEKSI KABEL USB (OTG)
          if (_printerModeIndex == 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DAFTAR PRINTER KABEL USB (OTG):',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Pindai USB', style: TextStyle(fontSize: 12)),
                  onPressed: _loadUsbPrinters,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tancapkan kabel data USB printer ke tablet/HP menggunakan adaptor USB OTG (Type-C atau Micro USB). Koneksi kabel sangat cepat dan tidak memerlukan pairing.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF134E4A), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_usbPrinters.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'Belum ada printer USB yang tertancap.\nPastikan kabel printer terhubung ke port charger tablet/HP dengan adaptor OTG, nyalakan printer, lalu tekan tombol "Pindai USB".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _usbPrinters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final u = _usbPrinters[idx];
                  final name = u['name']?.toString() ?? 'Printer USB Kasir';
                  final devId = u['deviceId']?.toString() ?? '';
                  final isConn = printer.connectedPrinterAddress == devId && printer.connectionType == 'USB';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isConn ? Colors.green : Colors.grey.shade200, width: isConn ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.usb, color: isConn ? Colors.green : Colors.teal.shade700),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              Text('Device ID: $devId (Vendor: ${u['vendorId'] ?? '-'})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (isConn)
                          OutlinedButton(
                            onPressed: () async {
                              await printer.disconnectUsb();
                              setState(() {});
                            },
                            child: const Text('Putuskan'),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isConnectingPrinter
                                ? null
                                : () async {
                                    setState(() => _isConnectingPrinter = true);
                                    final ok = await printer.connectUsb(devId, name);
                                    setState(() => _isConnectingPrinter = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Berhasil terhubung ke $name via Kabel USB!' : 'Gagal menghubungkan ke $name. Periksa izin USB.'),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                            child: const Text('Hubungkan Kabel'),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
