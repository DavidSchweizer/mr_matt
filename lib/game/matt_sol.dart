import 'dart:io';

// ignore: unused_import
import 'package:mr_matt/log.dart';

import 'matt_game.dart';

class MattLevelSolution {
  late int level;
  late int nrMoves;
  late String player;
  late String game;
  late List<MoveRecord> moves;
  late int checksum; // this is not used, so we can omit it
  MattLevelSolution({required this.level,required this.nrMoves, required this.player, required this.game, required this.moves, this.checksum=0});
}

class MattSolutionFile {
  static String linePattern = r"(?<level>\d+)[A-Z]\s(?<nrmoves>\d+)\s(?<player>.*?)\|(?<game>.*?)\|(?<moves>[\dUDRL]+)\s(?<checksum>\d+)";
  final RegExp lineRegex = RegExp(linePattern);
  static String movePattern= r"(?<repeat>\d(\d)?)?(?<move>[LUDR])";
  final RegExp moveRegex = RegExp(movePattern);
  String _filename="";
  String get filename=>_filename;
  String _versionLine="";
  String get versionLine=>_versionLine;
  List<MattLevelSolution> solutions=[];

  Future parseFile(String filename) async {
    _filename=filename;
    List<String> lines = await readLines(filename);
    parseVersionLine(lines[0]);
    for (int i = 1; i < lines.length; i++){
      solutions.add(parseLevel(lines[i]));
    }
  }
  void parseVersionLine(String line){
    _versionLine = line.trim();    
  }
  MattLevelSolution parseLevel(String line) {    
    Map<String,String> matchedNames = _parseLine(line);
    MattLevelSolution newLevelSolution = MattLevelSolution(
      level: int.tryParse(matchedNames['level']!)??0, 
      nrMoves: int.tryParse(matchedNames['nrmoves']!)??0, 
      player: matchedNames['player']!, 
      game: matchedNames['game']!, 
      moves: _parseMoves(matchedNames['moves']!),
      checksum: int.tryParse(matchedNames['checksum']!)??0);
    return newLevelSolution;
  }
  Map<String,String> _parseLine(String line) {     
    RegExpMatch? match = lineRegex.firstMatch(line);
    if (match == null) {
      throw('unexpected line in solution file:\n\t[$line]');
    }
    Map<String,String> matchedNames = {};
    for (String name in match.groupNames) {
      String? matchedName = match.namedGroup(name);
      if (matchedName == null) {
        throw('Missing field $name in line\n\t[$line]');
      }
      matchedNames[name]= matchedName;
    }
    return matchedNames;
  }
  List<MoveRecord> _parseMoves(String moves) {
    List<MoveRecord> result = [];
    for (RegExpMatch match in moveRegex.allMatches(moves)) {
      int repeat = (match.namedGroup('repeat') == null)? 0 : int.tryParse(match.namedGroup('repeat')!)??0;
      result.add(MoveRecord(repeat: repeat, move: moveFromCode[match.namedGroup('move')!]??Move.none));
    }
    return result;
  }
  Future <List<String>> readLines(String filename) async {
    final File file = File(filename);
    return file.readAsLines();
  }
}