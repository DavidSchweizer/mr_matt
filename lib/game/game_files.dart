import 'package:mr_matt/game/matt_file.dart';
import 'package:mr_matt/game/matt_game.dart';
import 'package:mr_matt/game/matt_hof.dart';
import 'package:mr_matt/game/matt_sol.dart';
import 'package:path/path.dart' as p;

class GameFiles{

  Map<String,MattFiles> matFileData = {};
  Map<String,MattSolutionFile> solutions = {};
  Map<String,MattHallOfFameFile> hallOfFames = {};
  String currentMatDirectory = "";
  String versionLine = 'Version 3.6 #1899 (temporary)'; 
  String allSolutionsFile = 'mr_matt.sol';

  Future<bool> loadMatFileData(String directory) async {
    directory = p.canonicalize(directory);
    if (matFileData[directory] != null) {// already loaded 
      return false;
    }
    MattFiles newData = MattFiles();
    await newData.readDirectory(directory);
    if (newData.isEmpty) {return false; }
    matFileData[directory] = newData;
    currentMatDirectory = directory;
    return true;
  }
  MattFiles _currentMattFiles() => matFileData[currentMatDirectory]?? MattFiles();
  MattFiles get currentMatFiles=>_currentMattFiles();

  int getNrMattFiles() {
    MattFiles files = _currentMattFiles();
    return files.nrFiles;
  }
  Iterable<MattFile> getMatFile() sync* {
    MattFiles files = _currentMattFiles();
    for (MattFile file in files.mattFiles) {yield file;}
  }

  // String _solutionFileName(String directory, String gameFileName){
  //   const String solExtension = '.sol';
  //   String gameName= p.basenameWithoutExtension(gameFileName);
  //   directory = p.canonicalize(directory);
  //   return p.join(directory, gameName, solExtension);
  // }

  Future <bool> updateSolution(String filename, String player, MattGame game, [save=false]) async {
    MattSolutionFile solutionFile = solutions[filename]??MattSolutionFile();
    solutionFile.update(player, game.title, game.level, game.getMoves());
    solutions[filename] = solutionFile;    
    if (save) {return saveSolutionFile(filename);}
    return true;
  }
  // Future<bool> _loadSolutionFile(String directory, String gameFileName) async {
  //   return await loadSolutionFile(_solutionFileName(directory, gameFileName));
  // }
  int highestSolutionLevel(String filename, String player, String gameTitle) {
    MattSolutionFile? solution = solutions[filename];
    if (solution == null) {return 0;}
    else {
      return solution.highestLevel(player: player, gameTitle: gameTitle);
    }
  }
  MattLevelMoves? findSolution(MattFile file, int level) {
    for (String solutionFileName in solutions.keys){
      MattSolutionFile solutionFile = solutions[solutionFileName]!;
      MattLevelMoves? mattLevelMoves = solutionFile.findEntry(gameTitle: file.title, level: level);
      if (mattLevelMoves != null) { 
        return mattLevelMoves;
      }
    }
    return null;
  }

  bool hasSolution(MattFile file, int level) {
    return findSolution(file,level) != null;
  }

  Future<bool> loadSolutionFile(String filename) async {
    MattSolutionFile newSolution = MattSolutionFile();
    bool result = await newSolution.parseFile(filename);
    if (result) {solutions[filename] = newSolution;}
    return result;
  }
  Future <bool> saveSolutionFile(String filename) async {
    MattSolutionFile? solution = solutions[filename];
    if (solution == null) {return false;}
    return solution.writeToFile(filename);
  }
  Future<bool>saveGameFile(String player, MattGame game, int level, String gameFileName) {    
    MattSolutionFile saveGame = MattSolutionFile(complete: game.nrFood==0);
    saveGame.versionLine = versionLine;
    saveGame.update(player, game.title, level, game.getMoves());
    return saveGame.writeToFile(gameFileName);    
  }

  Future<bool> loadHallOfFameFile(String directory) async {
    const String hallOfFame = 'mrmatt.hof';
    directory = p.canonicalize(directory);
    String hallOfFameFile = p.join(directory,hallOfFame);
    MattHallOfFameFile newHOF = MattHallOfFameFile();
    bool result = await newHOF.parseFile(hallOfFameFile);
    if (result) {hallOfFames[hallOfFameFile] = newHOF;}
    return result;
  }
}
