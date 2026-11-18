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
  String? connectionType; // 'USB' | 'BLUETOOTH' | null

  // ==================== BLUETOOTH ====================
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
        connectionType = 'BLUETOOTH';
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
      if (connectionType == 'BLUETOOTH') {
        connectedPrinterAddress = null;
        connectedPrinterName = null;
        connectionType = null;
      }
    } catch (_) {}
  }

  // ==================== USB CABLE (OTG) ====================
  Future<List<Map<String, dynamic>>> getUsbDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getUsbDevices');
      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> connectUsb(String? deviceId, String name) async {
    try {
      final bool? success = await _channel.invokeMethod('connectUsb', {'deviceId': deviceId});
      if (success == true) {
        connectedPrinterName = name;
        connectedPrinterAddress = deviceId;
        connectionType = 'USB';
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnectUsb() async {
    try {
      await _channel.invokeMethod('disconnectUsb');
      if (connectionType == 'USB') {
        connectedPrinterAddress = null;
        connectedPrinterName = null;
        connectionType = null;
      }
    } catch (_) {}
  }

  // ==================== STATUS & AUTO-CONNECT ====================
  Future<bool> isConnected() async {
    try {
      final bool? connected = await _channel.invokeMethod('isConnected');
      return connected == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getConnectionStatus() async {
    try {
      final res = await _channel.invokeMethod('getConnectionStatus');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['connected'] == true) {
          connectionType = map['type']?.toString();
          connectedPrinterName = map['name']?.toString();
        } else {
          connectionType = null;
          connectedPrinterName = null;
        }
        return map;
      }
    } catch (_) {}
    return {'connected': false, 'type': 'NONE', 'name': null};
  }

  /// Otomatis mendeteksi dan menghubungkan ke Printer Kabel USB atau Bluetooth
  Future<bool> autoConnect() async {
    try {
      final res = await _channel.invokeMethod('autoConnect');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['success'] == true) {
          connectionType = map['type']?.toString();
          connectedPrinterName = map['name']?.toString() ?? (connectionType == 'USB' ? 'Printer Kabel USB' : 'Printer Bluetooth');
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ==================== PDF ENGINE ====================
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

  // ==================== CETAK STRUK VVPAT (KOTAK SUARA) ====================
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
    // 1. Pastikan koneksi printer aktif, jika belum aktif coba auto-connect
    final bool connected = await isConnected();
    if (!connected) {
      await autoConnect();
    }

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

  /// Pembuat perintah biner ESC/POS super hemat kertas & font seragam kecil
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

    // 2. Set semua ukuran font sama kecil/normal (TIDAK DOUBLE SIZE/HEIGHT)
    bytes.addAll([0x1B, 0x21, 0x00]); // Standard Font A, normal
    bytes.addAll([0x1D, 0x21, 0x00]); // Normal Width/Height (1x)

    // 3. Header Ringkas (Center Align)
    bytes.addAll([0x1B, 0x61, 0x01]); // Center
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll(utf8.encode("PILKADES 2026 KARANG MUKTI\n"));
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF
    bytes.addAll(utf8.encode("KEC. CIPEUNDEUY - SUBANG\n"));
    bytes.addAll(utf8.encode("--------------------------------\n"));
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll(utf8.encode("BUKTI FISIK KOTAK SUARA (VVPAT)\n"));
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF
    bytes.addAll(utf8.encode("--------------------------------\n"));

    // 4. Data Pemilih & NIK (Left Align)
    bytes.addAll([0x1B, 0x61, 0x00]); // Left Align

    // Waktu format dd/MM/yy HH:mm:ss WIB (pas 1 baris, tidak terpotong)
    final now = DateFormat('dd/MM/yy HH:mm:ss').format(DateTime.now());
    bytes.addAll(utf8.encode("TPS   : TPS 01 KARANG MUKTI\n"));
    bytes.addAll(utf8.encode("WAKTU : $now WIB\n"));

    final name = (voterName != null && voterName.isNotEmpty) ? voterName : 'PEMILIH';
    bytes.addAll(utf8.encode("NAMA  : $name\n"));

    final nik = (voterNik != null && voterNik.isNotEmpty) ? voterNik : '-';
    bytes.addAll(utf8.encode("NIK   : $nik\n"));

    bytes.addAll(utf8.encode("TOKEN : $tokenCode\n"));
    bytes.addAll(utf8.encode("--------------------------------\n"));

    // 5. Pilihan Tercatat (Center Align, Font Seragam Kecil)
    bytes.addAll([0x1B, 0x61, 0x01]); // Center Align
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll(utf8.encode("PILIHAN TERCATAT:\n"));
    bytes.addAll(utf8.encode("CALON $candidateLetter (No. $candidateNumber)\n"));
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF
    bytes.addAll(utf8.encode("$candidateName\n"));
    bytes.addAll(utf8.encode("--------------------------------\n"));

    // 6. Petunjuk Singkat 1 Baris
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold ON
    bytes.addAll(utf8.encode("MASUKKAN KE KOTAK SUARA FISIK\n"));
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold OFF

    // 7. Feed minimal 2 baris saja lalu potong (sangat hemat kertas)
    bytes.addAll([0x0A, 0x0A]);
    bytes.addAll([0x1D, 0x56, 0x00]); // Cut

    return Uint8List.fromList(bytes);
  }
}
