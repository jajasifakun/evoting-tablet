class Election {
  final int id;
  final String name;
  final String village;
  final String subdistrict;
  final String regency;
  final int year;
  final String status;
  final String kppsChairman;

  Election({
    required this.id,
    required this.name,
    required this.village,
    required this.subdistrict,
    required this.regency,
    required this.year,
    required this.status,
    required this.kppsChairman,
  });

  factory Election.fromMap(Map<String, dynamic> map) {
    return Election(
      id: map['id'],
      name: map['name'],
      village: map['village'],
      subdistrict: map['subdistrict'],
      regency: map['regency'],
      year: map['year'],
      status: map['status'],
      kppsChairman: map['kpps_chairman'] ?? 'Kasda, S.T.,M.T',
    );
  }
}

class Candidate {
  final int id;
  final int orderNumber;
  final String letter;
  final String name;
  final String photoAsset;
  final String vision;
  final String mission;

  Candidate({
    required this.id,
    required this.orderNumber,
    required this.letter,
    required this.name,
    required this.photoAsset,
    required this.vision,
    required this.mission,
  });

  factory Candidate.fromMap(Map<String, dynamic> map) {
    return Candidate(
      id: map['id'],
      orderNumber: map['order_number'],
      letter: map['letter'],
      name: map['name'],
      photoAsset: map['photo_asset'],
      vision: map['vision'] ?? '',
      mission: map['mission'] ?? '',
    );
  }
}

class Voter {
  final int id;
  final String nik;
  final String name;
  final String gender;
  final String rt;
  final String rw;
  final String? address;
  final bool hasVoted;
  final String? votedAt;

  Voter({
    required this.id,
    required this.nik,
    required this.name,
    required this.gender,
    required this.rt,
    required this.rw,
    this.address,
    required this.hasVoted,
    this.votedAt,
  });

  factory Voter.fromMap(Map<String, dynamic> map) {
    return Voter(
      id: map['id'],
      nik: map['nik'],
      name: map['name'],
      gender: map['gender'],
      rt: map['rt'],
      rw: map['rw'],
      address: map['address'],
      hasVoted: map['has_voted'] == 1,
      votedAt: map['voted_at'],
    );
  }
}

class VoterToken {
  final int id;
  final int? voterId;
  final String tokenCode;
  final String status; // 'unused', 'used', 'cancelled'
  final String? usedAt;

  VoterToken({
    required this.id,
    this.voterId,
    required this.tokenCode,
    required this.status,
    this.usedAt,
  });

  factory VoterToken.fromMap(Map<String, dynamic> map) {
    return VoterToken(
      id: map['id'],
      voterId: map['voter_id'],
      tokenCode: map['token_code'],
      status: map['status'],
      usedAt: map['used_at'],
    );
  }
}

class VoteResult {
  final Candidate candidate;
  final int count;
  final double percentage;

  VoteResult({
    required this.candidate,
    required this.count,
    required this.percentage,
  });
}
