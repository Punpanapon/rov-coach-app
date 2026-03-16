import 'package:rov_coach/data/hero_database.dart';

/// Master list of RoV hero names — derived from [RoVDatabase].
///
/// Use [RoVDatabase] directly when you need hero IDs, roles, or image paths.
/// This flat list remains for backward compatibility with existing models.
final List<String> rovHeroes = RoVDatabase.allHeroNames;

