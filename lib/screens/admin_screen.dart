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
  bool _isConnectingPrinter = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
    _loadPairedPrinters();
  }

  Future<void> _loadPairedPrinters() async {
    final list = await ThermalPrinterService.instance.getPairedDevices();
    if (mounted) {
      setState(() => _pairedPrinters = list);
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
      message: 'PERINGATAN: Seluruh suara hasil simulasi akan dihapus kembali ke 0 suara, dan seluruh 10 DPT serta QR Code diaktifkan kembali seperti TPS baru dibuka. Lanjutkan?',
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
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Rekap Suara'),
            Tab(icon: Icon(Icons.people), text: 'Daftar DPT (10)'),
            Tab(icon: Icon(Icons.qr_code_2), text: 'Token QR'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Undangan & Barcode'),
            Tab(icon: Icon(Icons.print), text: 'Printer Thermal'),
            Tab(icon: Icon(Icons.settings_backup_restore), text: 'Reset Simulasi'),
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
                const Text(
                  'Mengembalikan status 10 DPT menjadi "Belum Memilih" dan seluruh QR Code menjadi "Unused". Suara pemilih sebelumnya tetap tersimpan.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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

          // Tombol Buka Lembar Undangan Penuh
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.print),
              label: const Text(
                'BUKA & CETAK 10 SURAT UNDANGAN (PANDUAN JEMPOL)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvitationScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'DAFTAR KARTU UNDANGAN PEMILIH (10 DPT):',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
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

  // --- TAB 5: PENGATURAN PRINTER THERMAL KOTAK SUARA ---
  Widget _buildThermalPrinterTab() {
    final printer = ThermalPrinterService.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Status
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: printer.connectedPrinterName != null ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: printer.connectedPrinterName != null ? Colors.green.shade300 : Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  printer.connectedPrinterName != null ? Icons.print : Icons.print_disabled,
                  color: printer.connectedPrinterName != null ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.connectedPrinterName != null
                            ? 'Printer Terhubung: ${printer.connectedPrinterName}'
                            : 'Printer Thermal Belum Terhubung',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: printer.connectedPrinterName != null ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        printer.connectedPrinterName != null
                            ? 'Struk bukti coblos fisik akan otomatis dicetak saat pemilih menekan YA di bilik suara.'
                            : 'Aplikasi berjalan dalam mode Simulasi Layar (struk digital ditampilkan di layar tablet & bisa dicetak jika printer Bluetooth dihubungkan).',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Switch Otomatis Cetak
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cetak Otomatis Struk ke Kotak Suara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('Keluarkan struk fisik sesaat setelah pemilih mencoblos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
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

          const SizedBox(height: 24),

          // Tombol Aksi Uji Coba & Scan
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Cari Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _loadPairedPrinters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Test Cetak Struk Contoh', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final ok = await printer.printTestReceipt();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Perintah cetak terkirim ke printer thermal!' : 'Printer belum terhubung via Bluetooth.'),
                        backgroundColor: ok ? Colors.green : Colors.orange,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'DAFTAR PERANGKAT BLUETOOTH TERPASANG (PAIRED):',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pastikan printer thermal kasir kecil (58mm/80mm) sudah Anda pasangkan (pair) di menu Bluetooth tablet/HP terlebih dahulu.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          if (_pairedPrinters.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text(
                  'Belum ada printer Bluetooth terdeteksi.\nBuka Pengaturan Bluetooth tablet/HP, nyalakan printer thermal, dan pasangkan (pair) printer Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
                ),
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
                final isConnected = printer.connectedPrinterAddress == addr;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isConnected ? Colors.green : Colors.grey.shade200, width: isConnected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.print, color: isConnected ? Colors.green : Colors.indigo),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(addr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (isConnected)
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
                            backgroundColor: Colors.indigo.shade600,
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
                                      content: Text(ok ? 'Berhasil terhubung ke $name!' : 'Gagal menghubungkan ke $name.'),
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
      ),
    );
  }
}
