import 'dart:io';
import 'package:mr_matt/log.dart';

abstract class MattLineFileEntry {
  late int level;
  late int nrMoves;
  late String player;
  late String game;
  late int checksum; // this is not used in this implementation
  MattLineFileEntry({required this.level,required this.nrMoves, required this.player, required this.game, this.checksum=0}); 
  String toExport();
}

abstract class MattLineFile<FT extends MattLineFileEntry> {
  String _filename="";
  String get filename=>_filename;
  String _versionLine="";
  late RegExp lineRegex;
  String get versionLine=>_versionLine;
  final List<FT> entries=[];
  MattLineFileEntry? lastEntry;
  MattLineFile({required String linePattern}) {
    linePattern = linePattern;
    lineRegex = RegExp(linePattern);
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
        entries.add(parseLineEntry(lines[i]));
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
  FT newEntry({required int level, required int nrMoves, required String player, required String game, required int checksum, required Map<String,String>otherFields});  
  FT parseLineEntry(String line) {
    const Set<String> baseNames = {'level', 'nrmoves', 'player', 'game', 'checksum'};
    Map<String,String> matchedNames = _parseLine(line);
    Map<String,String> otherFields = {};
    matchedNames.forEach((name,value) {if (!baseNames.contains(name)) {otherFields[name] = value;}});
    return newEntry(level:int.tryParse(matchedNames['level']!)??0,
              nrMoves: int.tryParse(matchedNames['nrmoves']!)??0,
           player: matchedNames['player']!, 
           game: matchedNames['game']!, 
       checksum: int.tryParse(matchedNames['checksum']!)??0,
       otherFields: otherFields
              );
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
    final File file = File(filename);
    bool existing = await file.exists();
    if (!existing) {return [];}
    else {return file.readAsLines();}
  }
  void _writeToFile(IOSink file) {
    file.writeln(versionLine);
    for (FT entry in entries) {
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
  FT? find(String game, String player, [int level = 0]) {
    for (FT entry in entries) {
      if (game==entry.game && player==entry.player && level == entry.level) {
        return entry;
      }
    }
    return null;
  }
  FT? highestLevel(String game, String player) {
    FT? result = find(game,player);
    if (result!=null) {
      for (FT entry in entries) {
        if (entry != result && game==entry.game && player==entry.player && entry.level > result!.level) {result = entry;}
      }
    }
    return result;
  }    
}