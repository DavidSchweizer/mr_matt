import 'package:mr_matt/game/matt_file.dart';
import 'package:mr_matt/game/matt_hof.dart';
import 'package:mr_matt/game/matt_sol.dart';
import 'package:path/path.dart' as p;

class GameFiles{
  Map<String,MattFiles> matFileData = {};
  Map<String,MattSolutionFile> solutions = {};
  Map<String,MattHallOfFameFile> hallOfFames = {};
  String currentMatDirectory = "";
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

  String _solutionFileName(String directory, String gameFileName){
    const String solExtension = '.sol';
    String gameName= p.basenameWithoutExtension(gameFileName);
    directory = p.canonicalize(directory);
    return p.join(directory, gameName, solExtension);
  }
  Future<bool> loadSolutionFile(String directory, String gameFileName) async {
    MattSolutionFile newSolution = MattSolutionFile();
    String solFileName = _solutionFileName(directory, gameFileName);
    bool result = await newSolution.parseFile(solFileName);
    if (result) {solutions[solFileName] = newSolution;}
    return result;
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
