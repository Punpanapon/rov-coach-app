class HeroModel {
  final String id;
  final String name;
  final String mainRole;

  const HeroModel({
    required this.id,
    required this.name,
    required this.mainRole,
  });

  /// Generates asset path preserving original name casing (e.g. Zuka.jpg)
  String get imagePath => 'assets/heroes/$name.jpg';
}

class RoVDatabase {
  static const List<HeroModel> allHeroes = [
    // ⚔️ Dark Slayer Lane (ออฟเลน) — 26 heroes
    HeroModel(id: 'DS01', name: 'Lu Bu',       mainRole: 'Slayer'),
    HeroModel(id: 'DS02', name: 'Zuka',        mainRole: 'Slayer'),
    HeroModel(id: 'DS03', name: 'Maloch',      mainRole: 'Slayer'),
    HeroModel(id: 'DS04', name: 'Motos',       mainRole: 'Slayer'),
    HeroModel(id: 'DS05', name: 'Ryoma',       mainRole: 'Slayer'),
    HeroModel(id: 'DS06', name: 'Omen',        mainRole: 'Slayer'),
    HeroModel(id: 'DS07', name: 'Florentino',  mainRole: 'Slayer'),
    HeroModel(id: 'DS08', name: 'Yena',        mainRole: 'Slayer'),
    HeroModel(id: 'DS09', name: 'Qi',          mainRole: 'Slayer'),
    HeroModel(id: 'DS10', name: 'Allain',      mainRole: 'Slayer'),
    HeroModel(id: 'DS11', name: 'Tachi',       mainRole: 'Jungle'),
    HeroModel(id: 'DS12', name: 'Yan',         mainRole: 'Jungle'),
    HeroModel(id: 'DS13', name: 'Bijan',       mainRole: 'Slayer'),
    HeroModel(id: 'DS14', name: 'Biron',       mainRole: 'Slayer'),
    HeroModel(id: 'DS15', name: 'Charlotte',   mainRole: 'Slayer'),
    HeroModel(id: 'DS16', name: 'Skud',        mainRole: 'Slayer'),
    HeroModel(id: 'DS17', name: 'Amily',       mainRole: 'Slayer'),
    HeroModel(id: 'DS18', name: 'Astrid',      mainRole: 'Slayer'),
    HeroModel(id: 'DS19', name: 'Errol',       mainRole: 'Slayer'),
    HeroModel(id: 'DS20', name: 'Riktor',      mainRole: 'Slayer'),
    HeroModel(id: 'DS21', name: 'Roxie',       mainRole: 'Slayer'),
    HeroModel(id: 'DS22', name: 'Veres',       mainRole: 'Slayer'),
    HeroModel(id: 'DS23', name: 'Volkath',     mainRole: 'Slayer'),
    HeroModel(id: 'DS24', name: 'Taara',       mainRole: 'Slayer'),
    HeroModel(id: 'DS25', name: 'Marja',       mainRole: 'Slayer'),
    HeroModel(id: 'DS26', name: 'Edras',       mainRole: 'Jungle'),

    // 🌲 Jungle (ป่า) — 24 heroes
    HeroModel(id: 'JG01', name: 'Nakroth',      mainRole: 'Jungle'),
    HeroModel(id: 'JG02', name: 'Wukong',       mainRole: 'Jungle'),
    HeroModel(id: 'JG03', name: 'Kriknak',      mainRole: 'Jungle'),
    HeroModel(id: 'JG04', name: 'Kaine',        mainRole: 'Jungle'),
    HeroModel(id: 'JG05', name: 'Airi',         mainRole: 'Slayer'),
    HeroModel(id: 'JG06', name: 'Zill',         mainRole: 'Jungle'),
    HeroModel(id: 'JG07', name: 'Paine',        mainRole: 'Jungle'),
    HeroModel(id: 'JG08', name: 'Keera',        mainRole: 'Jungle'),
    HeroModel(id: 'JG09', name: 'Sinestrea',    mainRole: 'Jungle'),
    HeroModel(id: 'JG10', name: 'Aoi',          mainRole: 'Jungle'),
    HeroModel(id: 'JG11', name: 'Butterfly',    mainRole: 'Jungle'),
    HeroModel(id: 'JG12', name: 'Murad',        mainRole: 'Jungle'),
    HeroModel(id: 'JG13', name: 'Quillen',      mainRole: 'Jungle'),
    HeroModel(id: 'JG14', name: 'Zephys',       mainRole: 'Jungle'),
    HeroModel(id: 'JG15', name: 'Zanis',        mainRole: 'Jungle'),
    HeroModel(id: 'JG16', name: 'Enzo',         mainRole: 'Jungle'),
    HeroModel(id: 'JG17', name: "D'Arcy",       mainRole: 'Jungle'),
    HeroModel(id: 'JG18', name: 'Violet',       mainRole: 'Dragon'),
    HeroModel(id: 'JG19', name: 'Raz',          mainRole: 'Mid'),
    HeroModel(id: 'JG20', name: 'Rourke',       mainRole: 'Jungle'),
    HeroModel(id: 'JG21', name: 'Wiro',         mainRole: 'Support'),
    HeroModel(id: 'JG22', name: 'Superman',     mainRole: 'Slayer'),
    HeroModel(id: 'JG23', name: 'Wonder Woman', mainRole: 'Jungle'),
    HeroModel(id: 'JG24', name: "Kil'Groth",    mainRole: 'Jungle'),

    // 🔮 Mid Lane (เมจ) — 27 heroes
    HeroModel(id: 'MID01', name: 'Veera',      mainRole: 'Mid'),
    HeroModel(id: 'MID02', name: 'Krixi',      mainRole: 'Mid'),
    HeroModel(id: 'MID03', name: 'Diaochan',   mainRole: 'Mid'),
    HeroModel(id: 'MID04', name: 'Aleister',   mainRole: 'Mid'),
    HeroModel(id: 'MID05', name: 'Natalya',    mainRole: 'Mid'),
    HeroModel(id: 'MID06', name: 'Ilumia',     mainRole: 'Mid'),
    HeroModel(id: 'MID07', name: 'Lauriel',    mainRole: 'Mid'),
    HeroModel(id: 'MID08', name: 'Tulen',      mainRole: 'Mid'),
    HeroModel(id: 'MID09', name: 'Liliana',    mainRole: 'Mid'),
    HeroModel(id: 'MID10', name: 'Flash',      mainRole: 'Jungle'),
    HeroModel(id: 'MID11', name: 'Dirak',      mainRole: 'Mid'),
    HeroModel(id: 'MID12', name: 'Zata',       mainRole: 'Mid'),
    HeroModel(id: 'MID13', name: 'Lorion',     mainRole: 'Mid'),
    HeroModel(id: 'MID14', name: 'Iggy',       mainRole: 'Mid'),
    HeroModel(id: 'MID15', name: 'Yue',        mainRole: 'Mid'),
    HeroModel(id: 'MID16', name: 'Bonnie',     mainRole: 'Mid'),
    HeroModel(id: 'MID17', name: 'Erin',       mainRole: 'Dragon'),
    HeroModel(id: 'MID18', name: "Azzen'Ka",   mainRole: 'Mid'),
    HeroModel(id: 'MID19', name: 'Ignis',      mainRole: 'Mid'),
    HeroModel(id: 'MID20', name: 'Kahlii',     mainRole: 'Mid'),
    HeroModel(id: 'MID21', name: 'Jinnar',     mainRole: 'Mid'),
    HeroModel(id: 'MID22', name: 'Preyta',     mainRole: 'Mid'),
    HeroModel(id: 'MID23', name: 'Mganga',     mainRole: 'Mid'),
    HeroModel(id: 'MID24', name: 'Sephera',    mainRole: 'Mid'),
    HeroModel(id: 'MID25', name: 'Ishar',      mainRole: 'Mid'),
    HeroModel(id: 'MID26', name: 'Bright',     mainRole: 'Dragon'),
    HeroModel(id: 'MID27', name: 'Dyadia',     mainRole: 'Support'),

    // 🏹 Abyssal Dragon Lane (แครี่) — 22 heroes
    HeroModel(id: 'ADL01', name: 'Valhein',     mainRole: 'Dragon'),
    HeroModel(id: 'ADL02', name: 'Yorn',        mainRole: 'Dragon'),
    HeroModel(id: 'ADL03', name: 'Slimz',       mainRole: 'Dragon'),
    HeroModel(id: 'ADL04', name: 'Stuart',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL05', name: "Tel'Annas",   mainRole: 'Dragon'),
    HeroModel(id: 'ADL06', name: 'Lindis',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL07', name: 'Elsu',        mainRole: 'Dragon'),
    HeroModel(id: 'ADL08', name: 'Hayate',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL09', name: 'Capheny',     mainRole: 'Dragon'),
    HeroModel(id: 'ADL10', name: "Eland'orr",   mainRole: 'Dragon'),
    HeroModel(id: 'ADL11', name: 'Laville',     mainRole: 'Dragon'),
    HeroModel(id: 'ADL12', name: 'Thorne',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL13', name: 'Teeri',       mainRole: 'Dragon'),
    HeroModel(id: 'ADL14', name: 'Fennik',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL15', name: 'Wisp',        mainRole: 'Dragon'),
    HeroModel(id: 'ADL16', name: 'Moren',       mainRole: 'Dragon'),
    HeroModel(id: 'ADL17', name: 'Celica',      mainRole: 'Dragon'),
    HeroModel(id: 'ADL18', name: 'Bolt Baron',  mainRole: 'Slayer'),
    HeroModel(id: 'ADL19', name: 'Billow',      mainRole: 'Jungle'),
    HeroModel(id: 'ADL20', name: 'Heino',       mainRole: 'Mid'),
    HeroModel(id: 'ADL21', name: 'Gildur',      mainRole: 'Mid'),
    HeroModel(id: 'ADL22', name: 'Dextra',      mainRole: 'Slayer'),

    // 🛡️ Support & Roaming (โรมมิ่ง) — 27 heroes
    HeroModel(id: 'SUP01', name: 'Thane',       mainRole: 'Support'),
    HeroModel(id: 'SUP02', name: 'Mina',        mainRole: 'Support'),
    HeroModel(id: 'SUP03', name: 'Grakk',       mainRole: 'Support'),
    HeroModel(id: 'SUP04', name: 'Lumburr',     mainRole: 'Support'),
    HeroModel(id: 'SUP05', name: 'Cresht',      mainRole: 'Support'),
    HeroModel(id: 'SUP06', name: 'Arum',        mainRole: 'Support'),
    HeroModel(id: 'SUP07', name: 'Baldum',      mainRole: 'Support'),
    HeroModel(id: 'SUP08', name: "Y'bneth",     mainRole: 'Support'),
    HeroModel(id: 'SUP09', name: 'TeeMee',      mainRole: 'Support'),
    HeroModel(id: 'SUP10', name: 'Xeniel',      mainRole: 'Support'),
    HeroModel(id: 'SUP11', name: 'Alice',       mainRole: 'Support'),
    HeroModel(id: 'SUP12', name: 'Helen',       mainRole: 'Support'),
    HeroModel(id: 'SUP13', name: 'Annette',     mainRole: 'Support'),
    HeroModel(id: 'SUP14', name: 'Zip',         mainRole: 'Support'),
    HeroModel(id: 'SUP15', name: 'Krizzix',     mainRole: 'Support'),
    HeroModel(id: 'SUP16', name: 'Rouie',       mainRole: 'Support'),
    HeroModel(id: 'SUP17', name: 'Aya',         mainRole: 'Support'),
    HeroModel(id: 'SUP18', name: 'Ming',        mainRole: 'Support'),
    HeroModel(id: 'SUP19', name: 'Dolia',       mainRole: 'Support'),
    HeroModel(id: 'SUP20', name: 'Arduin',      mainRole: 'Support'),
    HeroModel(id: 'SUP21', name: 'Chaugnar',    mainRole: 'Support'),
    HeroModel(id: 'SUP22', name: 'Omega',       mainRole: 'Support'),
    HeroModel(id: 'SUP23', name: 'Toro',        mainRole: 'Support'),
    HeroModel(id: 'SUP24', name: 'Ormarr',      mainRole: 'Support'),
    HeroModel(id: 'SUP25', name: 'Max',         mainRole: 'Support'),
    HeroModel(id: 'SUP26', name: 'Ata',         mainRole: 'Support'),
    HeroModel(id: 'SUP27', name: 'Goverra',     mainRole: 'Mid'),
  ];

  /// All unique role labels used in the database.
  static const List<String> roles = ['Slayer', 'Jungle', 'Mid', 'Dragon', 'Support'];

  /// Filter heroes by role.
  static List<HeroModel> heroesByRole(String role) =>
      allHeroes.where((h) => h.mainRole == role).toList();

  /// Search heroes by name (case-insensitive).
  static List<HeroModel> searchByName(String query) {
    final q = query.toLowerCase();
    return allHeroes.where((h) => h.name.toLowerCase().contains(q)).toList();
  }

  /// Find a hero by exact name.
  static HeroModel? findByName(String name) {
    final matches = allHeroes.where((h) => h.name == name);
    return matches.isEmpty ? null : matches.first;
  }

  /// Get all hero names as a simple list.
  static List<String> get allHeroNames => allHeroes.map((h) => h.name).toList();
}
