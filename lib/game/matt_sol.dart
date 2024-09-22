import 'package:mr_matt/game/matt_line_file.dart';
import 'matt_game.dart';

class MattLevelMoves extends MattLineFileEntry{
  late Moves moves;
  MattLevelMoves({required this.moves,
                required super.player, required super.game, required super.level,
                super.checksum}): super(nrMoves: moves.nrMoves);
  String _moveExport(Move move, int repeat) {
    return '${repeat>0?repeat.toString():""}${moveToCode[move]}';
  }

  @override
  String toExport() {
    String firstPart = '${level+1}X $nrMoves $player|$game|';
    String movesPart = '';
    Move current = Move.none; 
    int repeat = 0;
    for (MoveRecord move in moves.moves){
      if (current == Move.none) {
        current = move.move;
        repeat = move.repeat;
      }
      else if (move.move == current) {
        repeat += move.repeat+1;
      }
      else {
        movesPart += _moveExport(current, repeat);
        current = move.move;
        repeat = move.repeat;
      }     
    }
    if (current!= Move.none) {
      movesPart += _moveExport(current, repeat);
    }
    return '$firstPart$movesPart $checksum';
  }
}
class MattSolutionFile extends MattLineFile<MattLevelMoves> {
  static String linePattern = r"(?<level>\d+)[A-Z]\s(?<nrmoves>\d+)\s(?<player>.*?)\|(?<game>.*?)\|(?<moves>[\dUDRL]+)\s(?<checksum>\d+)";
  late bool complete;
  MattSolutionFile({this.complete=true}): super(linePattern: linePattern);
  static String movePattern= r"(?<repeat>\d(\d)?)?(?<move>[LUDR])";
  final RegExp moveRegex = RegExp(movePattern);
  List<MattLevelMoves> get solutions=>entries;
  @override
  MattLevelMoves newEntry({required String player, required String game, required int level, required int nrMoves, required int checksum, required Map<String,String> otherFields}) {
    return MattLevelMoves(moves: _parseMoves(otherFields['moves']!), 
                          player: player, game: game, level: level-1, checksum: checksum); 
  }
  Moves _parseMoves(String moves) {
    Moves result = Moves();
    for (RegExpMatch match in moveRegex.allMatches(moves)) {
      int repeat = (match.namedGroup('repeat') == null)? 0 : int.tryParse(match.namedGroup('repeat')!)??0;
      result.addMove(MoveRecord(repeat: repeat, move: moveFromCode[match.namedGroup('move')!]??Move.none));
    }
    return result;
  }
  bool update(String player, String game, int level, Moves moves) {
    MattLevelMoves? current = find(player, game,level);
    if (current == null) {
      entries.add(MattLevelMoves(moves: moves, player: player, game: game, level: level, ));
      return true;
    }
    else if (moves.nrMoves < current.nrMoves) {
      current.moves = moves;
      return true;
    }
    return false;
  }  
}

