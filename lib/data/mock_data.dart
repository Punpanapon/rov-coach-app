import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/player.dart';
import 'package:rov_coach/data/models/strategy.dart';
import 'package:rov_coach/data/models/scrim_match.dart';

/// Provides seed data for the app so the Coach can see a populated roster
/// and sample strategies right away.
class MockData {
  MockData._();

  static List<Player> get players => [
        const Player(
          id: 'p1',
          ign: 'ShadowKing',
          mainRole: PlayerRole.slayerLane,
          comfortPicks: ['Florentino', 'Allain', 'Yena', 'Qi'],
          weakPicks: ['Omen', 'Roxie'],
        ),
        const Player(
          id: 'p2',
          ign: 'JungleDiff',
          mainRole: PlayerRole.jungle,
          comfortPicks: ['Keera', 'Nakroth', 'Kriknak', 'Zephys'],
          weakPicks: ['Murad', 'Butterfly'],
        ),
        const Player(
          id: 'p3',
          ign: 'MidOrFeed',
          mainRole: PlayerRole.midLane,
          comfortPicks: ['Tulen', 'Liliana', 'Lorion', 'Zata'],
          weakPicks: ['Diao Chan', 'Ignis'],
        ),
        const Player(
          id: 'p4',
          ign: 'ADCarry99',
          mainRole: PlayerRole.abyssalDragonLane,
          comfortPicks: ['Laville', 'Capheny', 'Hayate', 'Tel\'Annas'],
          weakPicks: ['Elsu', 'Fennik'],
        ),
        const Player(
          id: 'p5',
          ign: 'ShieldBro',
          mainRole: PlayerRole.support,
          comfortPicks: ['Zip', 'Alice', 'Krizzix', 'Thane'],
          weakPicks: ['Lumburr', 'Mina'],
        ),
        const Player(
          id: 'p6',
          ign: 'FlexPick',
          mainRole: PlayerRole.midLane,
          comfortPicks: ['Paine', 'Raz', 'Lauriel'],
          weakPicks: ['Natalya'],
        ),
      ];

  static List<Strategy> get strategies => [
        const Strategy(
          id: 's1',
          name: 'Poke & Siege',
          composition: DraftComposition(
            slayerLane: 'Yena',
            jungle: 'Zephys',
            midLane: 'Tulen',
            abyssalDragonLane: 'Laville',
            support: 'Alice',
          ),
          executionGuide: ExecutionGuide(
            earlyGamePlan:
                'Play safe lanes, prioritize farm. Jungle focuses bot-side early invades.',
            midLateGamePlan:
                'Group mid, use Tulen + Laville poke to chunk enemies before objectives. Siege towers with Alice shield.',
            keyWinConditions:
                'Do NOT engage 5v5 head-on. Win through poke damage and tower pressure.',
          ),
        ),
        const Strategy(
          id: 's2',
          name: 'Dive Comp',
          composition: DraftComposition(
            slayerLane: 'Florentino',
            jungle: 'Nakroth',
            midLane: 'Liliana',
            abyssalDragonLane: 'Hayate',
            support: 'Zip',
          ),
          executionGuide: ExecutionGuide(
            earlyGamePlan:
                'Aggressive early ganks from Nakroth. Florentino plays for solo kills.',
            midLateGamePlan:
                'Use Zip delivery to engage onto backline. Nakroth + Florentino dive carries.',
            keyWinConditions:
                'Pick off enemy ADC or Mid before teamfight. If behind, split push with Florentino.',
          ),
        ),
        const Strategy(
          id: 's3',
          name: 'Protect the Carry',
          composition: DraftComposition(
            slayerLane: 'Qi',
            jungle: 'Keera',
            midLane: 'Lorion',
            abyssalDragonLane: 'Capheny',
            support: 'Thane',
          ),
          executionGuide: ExecutionGuide(
            earlyGamePlan:
                'Farm safely, protect Capheny lane. Keera ganks mid to snowball Lorion.',
            midLateGamePlan:
                'Thane + Qi frontline peels for Capheny. Lorion and Keera flank when enemies overcommit.',
            keyWinConditions:
                'Keep Capheny alive in teamfights at all costs. She is the primary damage source.',
          ),
        ),
      ];

  static List<ScrimMatch> get scrimMatches => [
        ScrimMatch(
          id: 'sm1',
          matchDate: DateTime(2026, 3, 1),
          opponentTeamName: 'Team Phoenix',
          strategyId: 's1',
          result: MatchResult.win,
          coachNotes: 'Poke plan worked perfectly. Enemy had no engage.',
        ),
        ScrimMatch(
          id: 'sm2',
          matchDate: DateTime(2026, 3, 2),
          opponentTeamName: 'Team Phoenix',
          strategyId: 's1',
          result: MatchResult.win,
          coachNotes: 'Solid macro. Need to improve early dragon control.',
        ),
        ScrimMatch(
          id: 'sm3',
          matchDate: DateTime(2026, 3, 3),
          opponentTeamName: 'Cyber Wolves',
          strategyId: 's2',
          result: MatchResult.loss,
          coachNotes:
              'Nakroth fell behind early. Dive timing was off. Regroup needed.',
        ),
        ScrimMatch(
          id: 'sm4',
          matchDate: DateTime(2026, 3, 4),
          opponentTeamName: 'Cyber Wolves',
          strategyId: 's2',
          result: MatchResult.win,
          coachNotes: 'Much better execution on the dive. Zip ult was clutch.',
        ),
        ScrimMatch(
          id: 'sm5',
          matchDate: DateTime(2026, 3, 5),
          opponentTeamName: 'Dragon Slayers',
          strategyId: 's3',
          result: MatchResult.loss,
          coachNotes:
              'Capheny got caught twice. Need better ward coverage around objectives.',
        ),
      ];
}
