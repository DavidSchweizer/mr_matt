import 'package:mr_matt/game/matt_line_file.dart';

class MattLevelHallOfFameEntry extends MattLineFileEntry {
  int seconds;
  MattLevelHallOfFameEntry({required this.seconds, required super.player, required super.gameTitle, required super.level,required super.nrMoves, super.checksum});  
  @override String toExport() {
    return '$level $seconds $nrMoves $gameTitle|$player|$checksum';
  }
}

class MattHallOfFameFile extends MattLineFile<MattLevelHallOfFameEntry>{
  static String linePattern = r"(?<level>\d+)\s(?<seconds>\d+)\s(?<nrmoves>\d+)\s(?<game>.*?)\|(?<player>.*?)\|(?<checksum>\d+)";
  MattHallOfFameFile(): super(linePattern: linePattern);
  @override
  MattLevelHallOfFameEntry newEntry({required String player, required String gameTitle, required int level, 
                                    required int nrMoves, required int checksum, required Map<String,String> otherFields}) {
    return MattLevelHallOfFameEntry(seconds: int.tryParse(otherFields['seconds']!)??0, 
            player: player, gameTitle: gameTitle, level: level, nrMoves: nrMoves);
  }
  bool update(String player, String game, int level, int seconds, int nrMoves) {
    MattLevelHallOfFameEntry? current = findEntry(player:player,gameTitle:game,level:level);
    if (current == null) {
      entries.add(MattLevelHallOfFameEntry(player: player, gameTitle: game, level: level, seconds: seconds, nrMoves: nrMoves));
      return true;
    }
    else if (current.nrMoves > nrMoves || current.nrMoves == nrMoves && current.seconds > seconds) {
      current.nrMoves = nrMoves;
      current.seconds = seconds;
      return true;
    }
    return false;
  }  
}