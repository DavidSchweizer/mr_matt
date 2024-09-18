import "dart:io";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "matt_grid.dart";
import "matt_level.dart";

//TO DO: exception handling, reading custom files, checksum checking

class MattFile {
  String _filename="";
  String get filename=>_filename;
  String _title="";
  String get title=>_title;
  String _author="";
  String get author=>_author;
  String _checkLine="";

  Rating _rating = Rating.unknown;
  Rating get rating => _rating;
  final List<MattLevel> _levels = [];
  List<MattLevel> get levels => _levels;
  int get nrLevels=>_levels.length;

  bool isNotEmpty() {
    return _levels.isNotEmpty;
  }
  void parseTitle(String line){
    line = line.trimLeft();
    int stars = 0;
    while (stars < line.length && line[stars] == '*') { stars++;}
    switch(stars){
      case 1: _rating = Rating.easy; break;
      case 2: _rating = Rating.moderate; break;
      case 3: _rating = Rating.hard; break;
      case 4: _rating = Rating.tough; break;
    }
    _title = line.substring(stars).trim();    
  }
  List<String> parseHeader(List<String> lines) {
    /* note: this only works for the original game files
             in the custom files, there is an extra line at the top (Version x.x. #y) 
             which is connected to the mrmatt version and the registration (presumably)
             also the levels are "encrypted" in some way, maybe also connected to the registration
             without extra info, these files can not be read yet.
    */
    parseTitle(lines[0]);
    _author = lines[1];
    _checkLine = lines[2]; // don't know how this is computed, so can not check
    return lines.sublist(3);   
  }
  List<String> parseLevel(List<String> lines) {    
    int level = levels.length+1;
    MattLevel newLevel = MattLevel(level, lines[0], level == 1);
    for(int row in GridConst.rowRange()){
      String line = lines[row+1].padRight(GridConst.mattWidth);
      for(int col in GridConst.colRange()){
        newLevel.grid.setCell(row,col,Tile.parse(line[col]));
      }    
    }
    newLevel.checkLine = lines[GridConst.mattHeight+1];
    levels.add(newLevel);
    return lines.sublist(GridConst.mattHeight+2);
  }
  Future parseFile(String filename) async {
    _filename=filename;
    List<String> lines = await readLines(filename);
    lines = parseHeader(lines);
    do {
      lines = parseLevel(lines);
    } while (lines.length > GridConst.mattHeight);
    // lines should now only be the last line of the file ("END")
    // to be used for syntax checking?
  }

  Future <List<String>> readLines(String filename) async {
      final File file = File(filename);
      return file.readAsLines();
  }
  @override
  String toString() =>
  "filename: $filename: title: $title [rating: $rating] nr levels: ${levels.length}";
  
  void dump() {
    if (kDebugMode){
      print('filename: $filename');
      print('title: $title');
      print('author: $author');
      print('rating: $rating');
      int nLevels = levels.length;
      print('nr levels: $nLevels');
      print('checkLine: $_checkLine');
    }
  }
} // MattFile

class MattFiles {
  final List<MattFile> mattFiles = [];  
  bool get isEmpty=>mattFiles.isEmpty;
  bool get isNotEmpty=>mattFiles.isNotEmpty;
  int get nrFiles=>mattFiles.length;
  Future<List<String>> readDirectoryNames(String directoryPath) async {
    List<String> fileNames= [];
    Directory directory = Directory(directoryPath);    
    await for (final FileSystemEntity entity in directory.list(recursive:false, followLinks: false)) {
      if (entity is File) {
        String pathName = entity.path;
        if (p.extension(pathName).toLowerCase() == '.mat') {
          fileNames.add(pathName);
          // MattFile newFile = MattFile();
          // await newFile.parseFile(pathName);
          // files.add(newFile);
        }
      }
    }
    return fileNames;
  }    

  Future<MattFiles> readDirectory(String directoryPath) async {
    List<String> fileNames = await readDirectoryNames(directoryPath);
    for (String filename in fileNames){
      MattFile newFile = MattFile();
      await newFile.parseFile(filename);
      mattFiles.add(newFile);
    }
    return this;
  }
}
