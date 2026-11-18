import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pilkades_karangmukti.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Elections Table
    await db.execute('''
      CREATE TABLE elections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        village TEXT NOT NULL,
        subdistrict TEXT NOT NULL,
        regency TEXT NOT NULL,
        year INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        kpps_chairman TEXT NOT NULL DEFAULT 'Kasda, S.T.,M.T'
      )
    ''');

    // 2. Candidates Table
    await db.execute('''
      CREATE TABLE candidates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number INTEGER NOT NULL,
        letter TEXT NOT NULL,
        name TEXT NOT NULL,
        photo_asset TEXT NOT NULL,
        vision TEXT,
        mission TEXT
      )
    ''');

    // 3. Voters Table (DPT)
    await db.execute('''
      CREATE TABLE voters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nik TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        gender TEXT NOT NULL,
        rt TEXT NOT NULL,
        rw TEXT NOT NULL,
        address TEXT,
        has_voted INTEGER NOT NULL DEFAULT 0,
        voted_at TEXT
      )
    ''');

    // 4. Voter Tokens Table
    await db.execute('''
      CREATE TABLE voter_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voter_id INTEGER,
        token_code TEXT UNIQUE NOT NULL,
        status TEXT NOT NULL DEFAULT 'unused',
        used_at TEXT,
        FOREIGN KEY (voter_id) REFERENCES voters (id) ON DELETE SET NULL
      )
    ''');

    // 5. Votes Table (Kotak Suara Digital)
    await db.execute('''
      CREATE TABLE votes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidate_id INTEGER NOT NULL,
        vote_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (candidate_id) REFERENCES candidates (id)
      )
    ''');

    // 6. Audit Logs
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Populate Initial Seed Data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // A. Election
    await db.insert('elections', {
      'id': 1,
      'name': 'Pemilihan Kepala Desa Karang Mukti',
      'village': 'Karang Mukti',
      'subdistrict': 'Cipeundeuy',
      'regency': 'Subang',
      'year': 2026,
      'status': 'active',
      'kpps_chairman': 'Kasda, S.T.,M.T',
    });

    // B. Candidates (Calon A & Calon B)
    await db.insert('candidates', {
      'id': 1,
      'order_number': 1,
      'letter': 'A',
      'name': 'CALON A',
      'photo_asset': 'assets/images/candidate-a.png',
      'vision': 'Mewujudkan Desa Karang Mukti yang Maju, Transparan, Berdaya Saing, dan Sejahtera Berbasis Gotong Royong.',
      'mission': '1. Peningkatan pelayanan publik yang cepat, mudah, dan transparan.\n2. Pemerataan pembangunan infrastruktur jalan usaha tani dan permukiman.\n3. Penguatan ekonomi desa melalui BUMDes dan UMKM masyarakat Karang Mukti.\n4. Peningkatan tata kelola pemerintahan desa yang bersih dan akuntabel.',
    });

    await db.insert('candidates', {
      'id': 2,
      'order_number': 2,
      'letter': 'B',
      'name': 'CALON B',
      'photo_asset': 'assets/images/candidate-b.png',
      'vision': 'Terwujudnya Karang Mukti Mandiri, Agamis, Berkeadilan, dan Berakhlak Mulia Menuju Masyarakat Makmur.',
      'mission': '1. Meningkatkan kualitas sumber daya manusia desa melalui pendidikan dan pelatihan terpadu.\n2. Revitalisasi pertanian modern dan ketersediaan sarana prasarana produksi tani.\n3. Peningkatan program kesehatan lansia, ibu, dan balita di Posyandu.\n4. Pelestarian nilai-nilai kearifan lokal, kerukunan warga, dan keagamaan.',
    });

    // C. 10 Sample DPT Voters & Linked QR Tokens
    final voters = [
      {'nik': '3213051001900001', 'name': 'SULAEMAN', 'gender': 'L', 'rt': '01', 'rw': '01', 'address': 'Dusun Karang Anyar RT 01/01', 'token': 'KM2026-TEST-VOTE01'},
      {'nik': '3213055202880002', 'name': 'SITI FATIMAH', 'gender': 'P', 'rt': '01', 'rw': '01', 'address': 'Dusun Karang Anyar RT 01/01', 'token': 'KM2026-TEST-VOTE02'},
      {'nik': '3213051507750003', 'name': 'ASEP KURNIAWAN', 'gender': 'L', 'rt': '02', 'rw': '01', 'address': 'Dusun Karang Anyar RT 02/01', 'token': 'KM26-YT5P7U3MIGFZ'},
      {'nik': '3213056108820004', 'name': 'NURHAYATI', 'gender': 'P', 'rt': '02', 'rw': '01', 'address': 'Dusun Karang Anyar RT 02/01', 'token': 'KM26-SYNAV2PJQZRP'},
      {'nik': '3213052003920005', 'name': 'DEDEN KOMARUDIN', 'gender': 'L', 'rt': '03', 'rw': '01', 'address': 'Dusun Karang Mulya RT 03/01', 'token': 'KM26-GHEMWTKK1EOY'},
      {'nik': '3213054511940006', 'name': 'ENDAH SUHARTINI', 'gender': 'P', 'rt': '03', 'rw': '01', 'address': 'Dusun Karang Mulya RT 03/01', 'token': 'KM26-V6QT6BOZNTKE'},
      {'nik': '3213051204850007', 'name': 'TARYANA', 'gender': 'L', 'rt': '01', 'rw': '02', 'address': 'Dusun Karang Asih RT 01/02', 'token': 'KM26-1CJGBZ442EMG'},
      {'nik': '3213054909890008', 'name': 'RATNA WULANDARI', 'gender': 'P', 'rt': '01', 'rw': '02', 'address': 'Dusun Karang Asih RT 01/02', 'token': 'KM26-ILDBBU4D0IOS'},
      {'nik': '3213052306780009', 'name': 'MAMAN SUPARMAN', 'gender': 'L', 'rt': '02', 'rw': '02', 'address': 'Dusun Karang Asih RT 02/02', 'token': 'KM26-38SO66JCLAAJ'},
      {'nik': '3213056712800010', 'name': 'YAYAH ROKAYAH', 'gender': 'P', 'rt': '02', 'rw': '02', 'address': 'Dusun Karang Asih RT 02/02', 'token': 'KM26-ZYDPUAIZVJWV'},
    ];

    for (var i = 0; i < voters.length; i++) {
      final v = voters[i];
      final voterId = await db.insert('voters', {
        'nik': v['nik'],
        'name': v['name'],
        'gender': v['gender'],
        'rt': v['rt'],
        'rw': v['rw'],
        'address': v['address'],
        'has_voted': 0,
      });

      await db.insert('voter_tokens', {
        'voter_id': voterId,
        'token_code': v['token'],
        'status': 'unused',
      });
    }

    await db.insert('audit_logs', {
      'action': 'INITIALIZE_SYSTEM',
      'description': 'Inisialisasi sistem E-Voting Pilkades Karang Mukti 2026 di Tablet Android',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --- BUSINESS LOGIC METHODS ---

  Future<Election?> getElection() async {
    final db = await instance.database;
    final res = await db.query('elections', limit: 1);
    if (res.isNotEmpty) {
      return Election.fromMap(res.first);
    }
    return null;
  }

  Future<List<Candidate>> getCandidates() async {
    final db = await instance.database;
    final res = await db.query('candidates', orderBy: 'order_number ASC');
    return res.map((c) => Candidate.fromMap(c)).toList();
  }

  Future<Map<String, dynamic>> validateToken(String rawCode) async {
    final db = await instance.database;
    final cleanCode = rawCode.trim();

    if (cleanCode.isEmpty) {
      return {'valid': false, 'message': 'Kode QR tidak terdeteksi.'};
    }

    final res = await db.query('voter_tokens', where: 'token_code = ?', whereArgs: [cleanCode]);
    if (res.isEmpty) {
      return {'valid': false, 'message': 'QR Code tidak terdaftar dalam sistem DPT.'};
    }

    final token = VoterToken.fromMap(res.first);
    if (token.status == 'used') {
      return {'valid': false, 'message': 'QR Code ini sudah pernah digunakan untuk memilih!'};
    }

    if (token.status == 'cancelled') {
      return {'valid': false, 'message': 'QR Code ini telah dibatalkan oleh panitia.'};
    }

    // Ambil data pemilih jika tertaut
    Voter? voter;
    if (token.voterId != null) {
      final vRes = await db.query('voters', where: 'id = ?', whereArgs: [token.voterId]);
      if (vRes.isNotEmpty) {
        voter = Voter.fromMap(vRes.first);
      }
    }

    return {
      'valid': true,
      'token': token,
      'voter': voter,
      'message': 'QR Code valid.',
    };
  }

  Future<Map<String, dynamic>?> getVoterByToken(String tokenCode) async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT v.name, v.nik
      FROM voter_tokens vt
      JOIN voters v ON vt.voter_id = v.id
      WHERE vt.token_code = ?
      LIMIT 1
    ''', [tokenCode.trim()]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>> castVote(String tokenCode, int candidateId) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // 1. Validasi token status di transaksi
      final tokenRes = await txn.query('voter_tokens', where: 'token_code = ? AND status = ?', whereArgs: [tokenCode, 'unused']);
      if (tokenRes.isEmpty) {
        return {'success': false, 'message': 'Token sudah digunakan atau tidak berlaku.'};
      }

      final tokenData = tokenRes.first;
      final voterId = tokenData['voter_id'];
      final nowStr = DateTime.now().toIso8601String();

      // 2. Generate Kriptografi Hash Suara Anonim
      final uuid = const Uuid().v4();
      final voteHash = sha256.convert(utf8.encode('$uuid-$candidateId-$nowStr')).toString();

      // 3. Masukkan suara ke kotak suara digital
      await txn.insert('votes', {
        'candidate_id': candidateId,
        'vote_hash': voteHash,
        'created_at': nowStr,
      });

      // 4. Ubah status token menjadi USED
      await txn.update('voter_tokens', {
        'status': 'used',
        'used_at': nowStr,
      }, where: 'token_code = ?', whereArgs: [tokenCode]);

      // 5. Update kehadiran pemilih (DPT)
      if (voterId != null) {
        await txn.update('voters', {
          'has_voted': 1,
          'voted_at': nowStr,
        }, where: 'id = ?', whereArgs: [voterId]);
      }

      // 6. Catat audit log
      await txn.insert('audit_logs', {
        'action': 'VOTE_CASTED',
        'description': 'Suara berhasil dicatat pada bilik tablet dengan hash: ${voteHash.substring(0, 16)}...',
        'created_at': nowStr,
      });

      return {
        'success': true,
        'voteHash': voteHash,
      };
    });
  }

  Future<List<VoteResult>> getVoteResults() async {
    final db = await instance.database;
    final candidates = await getCandidates();

    final totalVotesRes = await db.rawQuery('SELECT COUNT(*) as total FROM votes');
    final totalVotes = (totalVotesRes.first['total'] as int?) ?? 0;

    List<VoteResult> results = [];
    for (var c in candidates) {
      final cRes = await db.rawQuery('SELECT COUNT(*) as ctotal FROM votes WHERE candidate_id = ?', [c.id]);
      final count = (cRes.first['ctotal'] as int?) ?? 0;
      final percentage = totalVotes > 0 ? (count / totalVotes) * 100 : 0.0;

      results.add(VoteResult(
        candidate: c,
        count: count,
        percentage: percentage,
      ));
    }

    return results;
  }

  Future<int> getTotalVotersCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM voters');
    return (res.first['count'] as int?) ?? 0;
  }

  Future<int> getVotedVotersCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM voters WHERE has_voted = 1');
    return (res.first['count'] as int?) ?? 0;
  }

  Future<List<Voter>> getAllVoters() async {
    final db = await instance.database;
    final res = await db.query('voters', orderBy: 'id ASC');
    return res.map((m) => Voter.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getTokensWithVoters() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT vt.token_code, vt.status, vt.used_at, v.name as voter_name, v.nik as voter_nik
      FROM voter_tokens vt
      LEFT JOIN voters v ON vt.voter_id = v.id
      ORDER BY vt.id ASC
    ''');
  }

  // --- RESET SIMULATION METHODS ---

  Future<void> resetIndividualVoter(int voterId) async {
    final db = await instance.database;
    await db.update('voters', {'has_voted': 0, 'voted_at': null}, where: 'id = ?', whereArgs: [voterId]);
    await db.update('voter_tokens', {'status': 'unused', 'used_at': null}, where: 'voter_id = ?', whereArgs: [voterId]);
  }

  Future<void> resetIndividualToken(String tokenCode) async {
    final db = await instance.database;
    final res = await db.query('voter_tokens', where: 'token_code = ?', whereArgs: [tokenCode]);
    if (res.isNotEmpty) {
      final voterId = res.first['voter_id'];
      await db.update('voter_tokens', {'status': 'unused', 'used_at': null}, where: 'token_code = ?', whereArgs: [tokenCode]);
      if (voterId != null) {
        await db.update('voters', {'has_voted': 0, 'voted_at': null}, where: 'id = ?', whereArgs: [voterId]);
      }
    }
  }

  Future<void> resetAllVotersAndTokensOnly() async {
    final db = await instance.database;
    await db.update('voters', {'has_voted': 0, 'voted_at': null});
    await db.update('voter_tokens', {'status': 'unused', 'used_at': null});
  }

  Future<void> resetFullSimulation() async {
    final db = await instance.database;
    // 1. Kosongkan kotak suara
    await db.delete('votes');
    // 2. Aktifkan kembali semua DPT
    await db.update('voters', {'has_voted': 0, 'voted_at': null});
    // 3. Aktifkan kembali semua token QR
    await db.update('voter_tokens', {'status': 'unused', 'used_at': null});
  }
}
