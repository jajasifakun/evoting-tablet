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
              'Pastikan pilihan Anda sudah benar sebelum menyimpan suara:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Foto Kandidat Terpilih Diperbesar (Sesuai Permintaan User)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.indigo.shade300, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  candidate.photoAsset,
                  width: 170,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'NOMOR URUT ${candidate.orderNumber} • CALON ${candidate.letter}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              candidate.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ Pilihan bersifat rahasia dan tidak dapat diubah setelah dikonfirmasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600),
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

      // Pastikan data nama & NIK pemilih lengkap untuk dicetak di struk
      String? vName = widget.voter?.name;
      String? vNik = widget.voter?.nik;
      if (vNik == null || vNik.isEmpty) {
        final voterData = await DatabaseHelper.instance.getVoterByToken(widget.token.tokenCode);
        if (voterData != null) {
          vName ??= voterData['name']?.toString();
          vNik ??= voterData['nik']?.toString();
        }
      }

      // 1. Kirim cetak otomatis ke Printer Thermal (Kabel USB atau Bluetooth)
      if (ThermalPrinterService.instance.autoPrintEnabled) {
        ThermalPrinterService.instance.printVoteReceipt(
          candidateName: candidate.name,
          candidateLetter: candidate.letter,
          candidateNumber: candidate.orderNumber,
          tokenCode: widget.token.tokenCode,
          voteHash: voteHash,
          voterName: vName,
          voterNik: vNik,
        );
      }

      // 2. Langsung tampilkan layar instruksi kotak suara fisik & kembali otomatis ke Mulai Pemilihan
      // Pemilih TIDAK PERLU menekan tombol apapun!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SuccessScreen(candidate: candidate)),
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
                      height: 240,
                      width: 190,
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
