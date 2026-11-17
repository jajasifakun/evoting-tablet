import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThermalPrinterService {
  static final ThermalPrinterService instance = ThermalPrinterService._init();
  ThermalPrinterService._init();

  static const MethodChannel _channel = MethodChannel('com.evoting/thermal_printer');

  bool autoPrintEnabled = true;
  String? connectedPrinterName;
  String? connectedPrinterAddress;

  Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getPairedDevices');
      if (result == null) return [];
      return result.map((item) {
        final map = Map<String, dynamic>.from(item);
        return {
          'name': map['name']?.toString() ?? 'Printer Thermal',
          'address': map['address']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String address, String name) async {
    try {
      final bool? success = await _channel.invokeMethod('connect', {'address': address});
      if (success == true) {
        connectedPrinterAddress = address;
        connectedPrinterName = name;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      connectedPrinterAddress = null;
      connectedPrinterName = null;
    } catch (_) {}
  }

  Future<bool> isConnected() async {
    try {
      final bool? connected = await _channel.invokeMethod('isConnected');
      return connected == true;
    } catch (_) {
      return false;
    }
  }

  /// Buat file PDF dari gambar kartu undangan dan simpan ke memori perangkat
  Future<Map<String, dynamic>> createSinglePdf(String fileName, Uint8List bytes) async {
    try {
      final res = await _channel.invokeMethod('createSinglePdf', {
        'fileName': fileName,
        'bytes': bytes,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'error': 'Format respons tidak dikenali'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mulai dokumen PDF multi-halaman untuk batch cetak/unduh
  Future<bool> startMultiPagePdf(String fileName) async {
    try {
      final bool? ok = await _channel.invokeMethod('startMultiPagePdf', {'fileName': fileName});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Tambahkan satu halaman ke dokumen PDF aktif
  Future<bool> addPageToPdf(Uint8List bytes) async {
    try {
      final bool? ok = await _channel.invokeMethod('addPageToPdf', {'bytes': bytes});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Selesaikan dan simpan dokumen PDF multi-halaman
  Future<Map<String, dynamic>> finishMultiPagePdf() async {
    try {
      final res = await _channel.invokeMethod('finishMultiPagePdf');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'error': 'Format respons tidak dikenali'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Buka dokumen PDF di aplikasi pembaca PDF bawaan Android
  Future<bool> openPdf(String filePath) async {
    try {
      final bool? ok = await _channel.invokeMethod('openPdf', {'filePath': filePath});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Bagikan dokumen PDF ke WhatsApp / Cetak / Simpan ke File
  Future<bool> sharePdf(String filePath) async {
    try {
      final bool? ok = await _channel.invokeMethod('sharePdf', {'filePath': filePath});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Simpan file biner (gambar kartu undangan / struk) ke folder Download perangkat Android
  Future<bool> saveToDownloads(String fileName, Uint8List bytes) async {
    try {
      final bool? success = await _channel.invokeMethod('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
      });
      return success == true;
    } catch (_) {
      return false;
    }
  }

  /// Format dan kirim cetak struk bukti memilih (VVPAT) ke kotak suara fisik
  Future<bool> printVoteReceipt({
    required String candidateName,
    required String candidateLetter,
    required int candidateNumber,
    required String tokenCode,
    required String voteHash,
    String? voterName,
    String? voterNik,
  }) async {
    final bytes = generateReceiptBytes(
      candidateName: candidateName,
      candidateLetter: candidateLetter,
      candidateNumber: candidateNumber,
      tokenCode: tokenCode,
      voteHash: voteHash,
      voterName: voterName,
      voterNik: voterNik,
    );

    try {
      final bool? success = await _channel.invokeMethod('printRaw', {'bytes': bytes});
      return success == true;
    } catch (e) {
      return false;
    }
  }

  /// Cetak struk percobaan (test print)
  Future<bool> printTestReceipt() async {
    return await printVoteReceipt(
      candidateName: 'H. AHMAD SUBARJAH (CONTOH)',
      candidateLetter: 'A',
      candidateNumber: 1,
      tokenCode: 'KM2026-TEST-SAMPLE',
      voteHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      voterName: 'SIMULASI PETUGAS KPPS',
      voterNik: '3213050000000000',
    );
  }

  /// Pembuat perintah biner ESC/POS standar 58mm
  Uint8List generateReceiptBytes({
    required String candidateName,
    required String candidateLetter,
    required int candidateNumber,
    required String tokenCode,
    required String voteHash,
    String? voterName,
    String? voterNik,
  }) {
    final List<int> bytes = [];

    // 1. Reset / Inisialisasi printer ESC @
    bytes.addAll([0x1B, 0x40]);

    // 2. Center Align ESC a 1
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Header Double Height & Bold
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll([0x1D, 0x21, 0x11]); // Double Height/Width
    bytes.addAll(utf8.encode("PILKADES 2026\n"));
    bytes.addAll([0x1D, 0x21, 0x00]); // Normal Size
    bytes.addAll(utf8.encode("DESA KARANG MUKTI\n"));
    bytes.addAll(utf8.encode("KEC. CIPEUNDEUY - SUBANG\n"));
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF

    bytes.addAll(utf8.encode("================================\n"));
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(utf8.encode("BUKTI PEMUNGUTAN SUARA BILIK\n"));
    bytes.addAll(utf8.encode("(KERTAS KOTAK SUARA FISIK)\n"));
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll(utf8.encode("--------------------------------\n"));

    // 3. Left Align ESC a 0
    bytes.addAll([0x1B, 0x61, 0x00]);

    final now = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    bytes.addAll(utf8.encode("TPS      : TPS 01 KARANG MUKTI\n"));
    bytes.addAll(utf8.encode("WAKTU    : $now WIB\n"));
    bytes.addAll(utf8.encode("TOKEN QR : $tokenCode\n"));
    if (voterName != null && voterName.isNotEmpty) {
      bytes.addAll(utf8.encode("PEMILIH  : $voterName\n"));
    }
    bytes.addAll(utf8.encode("STATUS   : SUARA SAH TERCATAT\n"));
    bytes.addAll(utf8.encode("--------------------------------\n"));

    // 4. Center Align untuk pilihan
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(utf8.encode("PILIHAN TERCATAT:\n\n"));
    bytes.addAll([0x1D, 0x21, 0x11]); // Double Size
    bytes.addAll(utf8.encode("CALON $candidateLetter\n"));
    bytes.addAll(utf8.encode("(No. $candidateNumber)\n"));
    bytes.addAll([0x1D, 0x21, 0x00]); // Normal
    bytes.addAll(utf8.encode("$candidateName\n\n"));
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Audit Hash
    bytes.addAll(utf8.encode("--------------------------------\n"));
    bytes.addAll(utf8.encode("KODE VERIFIKASI DIGITAL:\n"));
    final shortHash = voteHash.length > 24 ? '${voteHash.substring(0, 12)}...${voteHash.substring(voteHash.length - 12)}' : voteHash;
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(utf8.encode("$shortHash\n"));
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Petunjuk Kotak Suara
    bytes.addAll(utf8.encode("================================\n"));
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(utf8.encode("*** INSTRUKSI PEMILIH ***\n"));
    bytes.addAll(utf8.encode("SOBEK STRUK BUKTI INI LALU\n"));
    bytes.addAll(utf8.encode("MASUKKAN KE DALAM KOTAK SUARA\n"));
    bytes.addAll(utf8.encode("FISIK SEBELUM KELUAR BILIK!\n"));
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll(utf8.encode("================================\n"));
    bytes.addAll(utf8.encode("Terima Kasih Atas Partisipasi\nDalam Pilkades Karang Mukti 2026\n\n"));

    // 5. Feed kertas 4 baris & pemotong (GS V 0)
    bytes.addAll([0x0A, 0x0A, 0x0A, 0x0A]);
    bytes.addAll([0x1D, 0x56, 0x00]);

    return Uint8List.fromList(bytes);
  }
}
