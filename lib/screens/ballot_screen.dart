import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../data/database_helper.dart';
import '../services/thermal_printer_service.dart';
import 'success_screen.dart';

class BallotScreen extends StatefulWidget {
  final VoterToken token;
  final Voter? voter;

  const BallotScreen({
    super.key,
    required this.token,
    this.voter,
  });

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  List<Candidate> _candidates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final list = await DatabaseHelper.instance.getCandidates();
    setState(() {
      _candidates = list;
      _isLoading = false;
    });
  }

  void _showConfirmationDialog(Candidate candidate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.how_to_vote, color: Colors.indigo.shade600, size: 28),
            const SizedBox(width: 8),
            const Text('Konfirmasi Pilihan Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pastikan pilihan Anda sudah benar sebelum menyimpan ke kotak suara digital:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      candidate.photoAsset,
                      width: 70,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NOMOR URUT ${candidate.orderNumber}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${candidate.letter} - ${candidate.name}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Pilihan Anda bersifat rahasia dan tidak dapat diubah setelah dikonfirmasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal / Ganti'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeVote(candidate);
            },
            child: const Text('YA, SAYA YAKIN (COBLOS)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeVote(Candidate candidate) async {
    final result = await DatabaseHelper.instance.castVote(widget.token.tokenCode, candidate.id);
    if (!mounted) return;

    if (result['success'] == true) {
      final voteHash = result['voteHash'] as String? ?? 'HASH-OK';

      // 1. Kirim cetak otomatis ke Printer Thermal (jika terhubung Bluetooth)
      if (ThermalPrinterService.instance.autoPrintEnabled) {
        ThermalPrinterService.instance.printVoteReceipt(
          candidateName: candidate.name,
          candidateLetter: candidate.letter,
          candidateNumber: candidate.orderNumber,
          tokenCode: widget.token.tokenCode,
          voteHash: voteHash,
          voterName: widget.voter?.name,
          voterNik: widget.voter?.nik,
        );
      }

      // 2. Tampilkan dialog bukti fisik & instruksi memasukkan ke Kotak Suara
      await _showReceiptModal(candidate, voteHash);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal menyimpan suara. Token sudah tidak berlaku.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReceiptModal(Candidate candidate, String voteHash) async {
    final now = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final shortHash = voteHash.length > 20 ? '${voteHash.substring(0, 10)}...${voteHash.substring(voteHash.length - 10)}' : voteHash;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animasi / Ikon Printer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.print, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'STRUK BUKTI PEMILIHAN DICETAK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // KERTAS STRUK THERMAL SIMULASI
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'PILKADES KARANG MUKTI 2026',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'KEC. CIPEUNDEUY - KAB. SUBANG',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    const Divider(thickness: 1, height: 16),
                    const Center(
                      child: Text(
                        'BUKTI PEMUNGUTAN SUARA FISIK (VVPAT)',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('TPS      : TPS 01 DESA KARANG MUKTI', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                    Text('WAKTU    : $now WIB', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                    Text('TOKEN QR : ${widget.token.tokenCode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                    if (widget.voter != null)
                      Text('PEMILIH  : ${widget.voter!.name}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                    const Divider(thickness: 1, height: 16),
                    Center(
                      child: Column(
                        children: [
                          const Text('PILIHAN ANDA TELAH TERCATAT:', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'CALON ${candidate.letter} (No. ${candidate.orderNumber})\n${candidate.name}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.indigo.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Kode Hash: $shortHash', style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // INSTRUKSI KOTAK SUARA FISIK (PENTING)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.amber.shade900, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PETUNJUK PEMILIH:',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.amber.shade900),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Ambil struk kertas yang keluar dari printer kecil, lalu segera masukkan ke dalam KOTAK SUARA FISIK.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF451A03), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Konfirmasi Telah Masuk Kotak Suara
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    'SAYA SUDAH MEMASUKKAN KE KOTAK SUARA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SURAT SUARA DIGITAL RESMI',
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              widget.voter != null
                  ? 'Pemilih: ${widget.voter!.name} (${widget.voter!.nik})'
                  : 'Token: ${widget.token.tokenCode}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        border: Border.all(color: Colors.amber.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sentuh salah satu kotak calon di bawah ini untuk menentukan pilihan Anda:',
                            style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Grid Kartu Calon A dan Calon B
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isTablet = constraints.maxWidth > 650;
                        return Flex(
                          direction: isTablet ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _candidates.map((c) {
                            return isTablet
                                ? Expanded(child: _buildCandidateCard(c))
                                : _buildCandidateCard(c);
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCandidateCard(Candidate candidate) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showConfirmationDialog(candidate),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Nomor Urut & Huruf
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NOMOR ${candidate.orderNumber}',
                        style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade600,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        candidate.letter,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Foto Calon
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      candidate.photoAsset,
                      height: 180,
                      width: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nama Calon
                Text(
                  candidate.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                // Visi Ringkas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    candidate.vision,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol Coblos
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: Text(
                      'PILIH CALON ${candidate.letter}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => _showConfirmationDialog(candidate),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
