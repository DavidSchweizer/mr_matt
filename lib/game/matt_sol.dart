import 'package:mr_matt/game/matt_line_file.dart';
import 'matt_game.dart';

class MattLevelSolution extends MattLineFileEntry{
  late List<MoveRecord> moves;
  MattLevelSolution({required this.moves, required super.level,required super.nrMoves, required super.player, required super.game, super.checksum});
  @override
  String toExport() {
    String firstPart = '${level}X $nrMoves $player|$game|';
    String movesPart = '';
    for (MoveRecord move in moves){
      movesPart += '${move.repeat>0?move.repeat.toString():""}${moveToCode[move.move]}';
    }
    return '$firstPart$movesPart $checksum';
  }
}
class MattSolutionFile extends MattLineFile<MattLevelSolution> {
  static String linePattern = r"(?<level>\d+)[A-Z]\s(?<nrmoves>\d+)\s(?<player>.*?)\|(?<game>.*?)\|(?<moves>[\dUDRL]+)\s(?<checksum>\d+)";
  MattSolutionFile(): super(linePattern: linePattern);
  static String movePattern= r"(?<repeat>\d(\d)?)?(?<move>[LUDR])";
  final RegExp moveRegex = RegExp(movePattern);
  List<MattLevelSolution> get solutions=>entries;
  @override
  MattLevelSolution newEntry({required int level, required int nrMoves, required String player, required String game, required int checksum, required Map<String,String> otherFields}) {
    return MattLevelSolution(moves: _parseMoves(otherFields['moves']!),level: level, nrMoves: nrMoves, player: player, game: game, checksum: checksum); 
  }
  List<MoveRecord> _parseMoves(String moves) {
    List<MoveRecord> result = [];
    for (RegExpMatch match in moveRegex.allMatches(moves)) {
      int repeat = (match.namedGroup('repeat') == null)? 0 : int.tryParse(match.namedGroup('repeat')!)??0;
      result.add(MoveRecord(repeat: repeat, move: moveFromCode[match.namedGroup('move')!]??Move.none));
    }
    return result;
  }
}