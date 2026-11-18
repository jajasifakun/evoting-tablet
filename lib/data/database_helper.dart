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
    _database = await _initDB('pilkades_tati.db');
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

    // B. Candidates (1: TARSIH, S.Pd & 2: Calon lain)
    await db.insert('candidates', {
      'id': 1,
      'order_number': 1,
      'letter': '1',
      'name': 'TARSIH, S.Pd',
      'photo_asset': 'assets/images/candidate-a.png',
      'vision': 'Mewujudkan Desa yang Maju, Transparan, Berdaya Saing, dan Sejahtera Berbasis Gotong Royong.',
      'mission': '1. Peningkatan pelayanan publik yang cepat, ramah, dan transparan.\n2. Pemerataan pembangunan sarana prasarana desa dan jalan usaha tani.\n3. Penguatan ekonomi warga desa melalui BUMDes dan pembinaan UMKM.\n4. Mewujudkan tata kelola pemerintahan desa yang amanah dan akuntabel.',
    });

    await db.insert('candidates', {
      'id': 2,
      'order_number': 2,
      'letter': '2',
      'name': 'Calon lain',
      'photo_asset': 'assets/images/candidate-b.png',
      'vision': 'Visi dan Misi Calon Alternatif.',
      'mission': 'Pilihan Calon Alternatif Pilkades.',
    });

    // C. 20 Sample DPT Voters & Linked QR Tokens
    final voters = [
      {'nik': '3213051403810001', 'name': 'DADANG SUHENDAR', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE01'},
      {'nik': '3213055808840002', 'name': 'NINA HERLINA', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE02'},
      {'nik': '3213052206790003', 'name': 'AGUS SETIAWAN', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE03'},
      {'nik': '3213056104860004', 'name': 'AI SITI ROHMAH', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE04'},
      {'nik': '3213051009830005', 'name': 'WAWAN KURNIA', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE05'},
      {'nik': '3213054711880006', 'name': 'ENI NURAENI', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE06'},
      {'nik': '3213050502760007', 'name': 'JAJANG HIDAYAT', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE07'},
      {'nik': '3213056305910008', 'name': 'RINA MARLINA', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE08'},
      {'nik': '3213051907800009', 'name': 'UDIN SAEPUDIN', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE09'},
      {'nik': '3213055212850010', 'name': 'TUTI ALAWIYAH', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE10'},
      {'nik': '3213052801820011', 'name': 'CECEP SUPRIATNA', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE11'},
      {'nik': '3213054903890012', 'name': 'LILIS SURYANI', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE12'},
      {'nik': '3213051608770013', 'name': 'IWAN RIDWAN', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE13'},
      {'nik': '3213056509930014', 'name': 'DEWI KARTIKA', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE14'},
      {'nik': '3213050804750015', 'name': 'YAYAT RUHIYAT', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE15'},
      {'nik': '3213055610870016', 'name': 'NENENG HASANAH', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE16'},
      {'nik': '3213052412830017', 'name': 'HERI HERMAWAN', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE17'},
      {'nik': '3213054106920018', 'name': 'SRI WAHYUNI', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE18'},
      {'nik': '3213051105800019', 'name': 'DENI RAMDANI', 'gender': 'L', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE19'},
      {'nik': '3213056907860020', 'name': 'KOKOM KOMALASARI', 'gender': 'P', 'rt': '09', 'rw': '05', 'address': 'Ciomas RT 09 RW 05', 'token': 'KM26-TATI-VOTE20'},
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
      'description': 'Inisialisasi sistem E-Voting Pilkades Tati di Tablet Android',
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
      SELECT vt.id as dpt_no, vt.token_code, vt.status, vt.used_at, v.name as voter_name, v.nik as voter_nik, v.rt, v.rw, v.address
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
