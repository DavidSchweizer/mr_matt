import 'dart:io';
import 'package:mr_matt/log.dart';

class MattLevelHallOfFameEntry {
  late int level;
  late int seconds;
  late int nrMoves;
  late String player;
  late String game;
  
  late int checksum; // this is not used, so we can ignore it for now
  MattLevelHallOfFameEntry({required this.level,required this.seconds, required this.nrMoves, required this.player, required this.game, this.checksum=0});
  String toExport() {
    return '$level $seconds $nrMoves $game|$player|$checksum';
  }
}

class MattHallOfFameFile {
  static String linePattern = r"(?<level>\d+)\s(?<seconds>\d+)\s(?<nrmoves>\d+)\s(?<game>.*?)\|(?<player>.*?)\|(?<checksum>\d+)";
  final RegExp lineRegex = RegExp(linePattern);
  String _filename="";
  String get filename=>_filename;
  String _versionLine="";
  String get versionLine=>_versionLine;
  final List<MattLevelHallOfFameEntry> entries=[];
  MattLevelHallOfFameEntry? find(String game, String player, [int level = 0]) {
    for (MattLevelHallOfFameEntry entry in entries) {
      if (game==entry.game && player==entry.player && level == entry.level) {
        return entry;
      }
    }
    return null;
  }
  MattLevelHallOfFameEntry? highestLevel(String game, String player) {
    MattLevelHallOfFameEntry? result = find(game,player);
    if (result!=null) {
      for (MattLevelHallOfFameEntry entry in entries) {
        if (entry != result && game==entry.game && player==entry.player && entry.level > result!.level) {result = entry;}
      }
    }
    return result;
  }
  bool update(String game, String player, int level, int seconds, int nrMoves) {
    MattLevelHallOfFameEntry? current = find(game,player,level);
    if (current == null) {
      entries.add(MattLevelHallOfFameEntry(level: level, seconds: seconds, nrMoves: nrMoves, player: player, game: game));
      return true;
    }
    else if (current.nrMoves > nrMoves || current.nrMoves == nrMoves && current.seconds > seconds) {
      current.nrMoves = nrMoves;
      current.seconds = seconds;
      return true;
    }
    return false;
  }  
  Future<bool> parseFile(String filename) async {
    _filename=filename;
    bool result = true;
    List<String> lines = await readLines(filename);
    if (lines.isEmpty) 
      { return false;}
    try {
      parseVersionLine(lines[0]);
      for (int i = 1; i < lines.length; i++){
        entries.add(parseLevel(lines[i]));
      }
    }
    on Exception catch(e) {
      logDebug('Error parsing file: $e');
      result = false;
    }
    return result;
  }
  void parseVersionLine(String line){
    _versionLine = line.trim();    
  }
  MattLevelHallOfFameEntry parseLevel(String line) {    
    Map<String,String> matchedNames = _parseLine(line);
    MattLevelHallOfFameEntry newLevelSolution = MattLevelHallOfFameEntry(
      level: int.tryParse(matchedNames['level']!)??0, 
      seconds: int.tryParse(matchedNames['seconds']!)??0, 
      nrMoves: int.tryParse(matchedNames['nrmoves']!)??0, 
      player: matchedNames['player']!, 
      game: matchedNames['game']!, 
      checksum: int.tryParse(matchedNames['checksum']!)??0);
    return newLevelSolution;
  }
  Map<String,String> _parseLine(String line) {     
    RegExpMatch? match = lineRegex.firstMatch(line);
    if (match == null) {
      throw('unexpected line pattern in solution file:\n\t[$line]');
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
  Future <List<String>> readLines(String filename) async {
    // filename = r"D:\mattproj\mr_matt\sol\mrmatt.hof";
    final File file = File(filename);
    bool existing = await file.exists();
    if (!existing) {return [];}
    else {return file.readAsLines();}
  }
  void _writeToFile(IOSink file) {
    file.writeln(versionLine);
    for (MattLevelHallOfFameEntry entry in entries) {
      file.writeln(entry.toExport());
    }
  }
  Future<bool> writeToFile(String filename) async {
    final IOSink file = File(filename).openWrite();
    file.done.catchError((e) { logDebug('error opening or writing to file $e');});
    bool result = true;
    try {
      _writeToFile(file);
    }
    on FileSystemException catch (e){
      logDebug('error writing file: $e');
      result = false;
    }
    finally {
      await file.flush();
      await file.close();
    }
    return result;
  }
  void clear() {
    _filename='';
    _versionLine='';
    entries.clear();
  }
}