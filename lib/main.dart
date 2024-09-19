import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mr_matt/game/game_files.dart';
import 'package:mr_matt/game/matt_hof.dart';
import 'package:mr_matt/widgets/buttons.dart';
import 'game/matt_file.dart';
import 'game/matt_game.dart';
import 'game/matt_grid.dart';
import 'game/matt_level.dart';
import 'log.dart';
import 'matt_select_file.dart';
import 'matt_widgets.dart';
import 'widgets/dialogs.dart';
import 'widgets/stopwatch.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MrMattApp());
}

class MrMattApp extends StatelessWidget {
  const MrMattApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mr. Matt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MrMattHome(title: 'Mr. Matt'),
    );
  }
}

class MrMattHome extends StatefulWidget {
  const MrMattHome({super.key, required this.title});
  final String title;

  @override
  State<MrMattHome> createState() => _MrMattHomeState();
}

class _MrMattHomeState extends State<MrMattHome> {
  final String matDirectory = p.canonicalize('mat');

  int _counter = 0;
  final MattAssets mattAssets = MattAssets();
  // MattFiles fileData = MattFiles();
  SecondsStopwatch stopwatch = SecondsStopwatch();
  LogicalKeyboardKey? lastKeyDown;
  MattFile selectedFile=MattFile();
  MattGame? game;
  MattFile? newFile;
  int? currentLevel;
  String player = "Mr David #1899";

  GameFiles gameFiles = GameFiles();
  
  // MattSolutionFile solutions = MattSolutionFile();
  MattHallOfFameFile solvedGameLevels = MattHallOfFameFile();
  
  bool _fileLoaded() =>selectedFile.isNotEmpty();
  bool _filesLoaded()=> gameFiles.currentMatFiles.isNotEmpty;
  bool _levelSelected() =>currentLevel!=null;
  bool _gameRunning()=>game!=null;

  MattLevel? getLevel() {
    if (_fileLoaded()&&_levelSelected()){
      return selectedFile.levels[currentLevel!];
    }
    else {return null;}
  }
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent keyEvent) {    
    bool isUp = keyEvent is KeyUpEvent;
    bool isDn = keyEvent is KeyDownEvent;    
    logDebug('key event detected:${keyEvent.logicalKey.debugName} (${isUp?"UP":(isDn?"DN":"Hmmm...")}) Last key: $lastKeyDown');
    if (keyEvent is KeyUpEvent && lastKeyDown == keyEvent.logicalKey) {
      lastKeyDown = null;
      return KeyEventResult.ignored;
    }
    else if (keyEvent is KeyDownEvent) 
      {lastKeyDown = keyEvent.logicalKey;}
    else {lastKeyDown = null;}
    KeyEventResult result = KeyEventResult.handled;
    switch (keyEvent.logicalKey){
      case LogicalKeyboardKey.arrowLeft: _gameMove(Move.left);
      case LogicalKeyboardKey.arrowRight: _gameMove(Move.right);
      case LogicalKeyboardKey.arrowUp: _gameMove(Move.up);
      case LogicalKeyboardKey.arrowDown: _gameMove(Move.down);
      case LogicalKeyboardKey.keyA: _gameMove(Move.left);
      case LogicalKeyboardKey.home: _repeatMove(Move.left);
      case LogicalKeyboardKey.end: _repeatMove(Move.right);
      case LogicalKeyboardKey.pageUp: _repeatMove(Move.up);
      case LogicalKeyboardKey.pageDown: _repeatMove(Move.down );
      case LogicalKeyboardKey.keyZ: 
        if (HardwareKeyboard.instance.isControlPressed) {
          _undoMove();
        }
      default: 
        result = KeyEventResult.ignored;
      }
    return result;
  }
  String _getLevelTitle() {
    if (_fileLoaded()&&_levelSelected()){
      return '${getLevel()!.title} (level ${(currentLevel??0)+1})';
    }
    else { return "no level selected";}
  }
  String _getTitle() {
    if (_fileLoaded()) {
      return '${selectedFile.title} - ${_getLevelTitle()}';
    }
    else { return "no file loaded: Load a file first!";}
  }
  @override
  Widget build(BuildContext context) {
    // MattAssets assets = MattAssets(defaultImageStyle);    
    Grid? grid = game?.grid;
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('Mr. Matt ($player) | ${_getTitle()}'),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.inversePrimary,
          elevation: 10,
          child:
          Row(children: [
            Column(
              children: [
                Row(
                  children: [
                    const Text("time:"),
                    StopwatchWidget(stopwatch: stopwatch),
                  ],
                ),
                Text('moves: $_counter'),
              ],
            ),
            
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
            
            MattAppBarButton(
                    onPressed: _moveLeft,
                    iconData: Icons.keyboard_arrow_left),
            MattAppBarButton(
                    onPressed: _moveUp,
                      iconData: Icons.keyboard_arrow_up),
            MattAppBarButton(
                    onPressed: _moveDown,
                    iconData: Icons.keyboard_arrow_down),
            MattAppBarButton(
                    onPressed: _moveRight,
                    iconData: Icons.keyboard_arrow_right),
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),                      
            MattAppBarButton(
                    onPressed: _restartGame,
                    iconData: Icons.restart_alt),
            MattAppBarButton(
                    onPressed: _undoMove,
                    iconData: Icons.undo),
            MattAppBarButton(
                    onPressed: _loader,
                    iconData: Icons.folder_open),
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
                const SizedBox(
                  width: 10,
                ),
            MattAppBarButton(
                    onPressed: _playback,
                    iconData: Icons.playlist_play),
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
                const SizedBox(
                  width: 10,
                ),
            MattLevelSelector(file: selectedFile, levelSelected: _selectLevel,),
              ]
              )
        ),
        body: Center(
          child:                       
            Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: 
            [Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width:754, height: 440, 
                child: 
                  Focus(onFocusChange: (bool value)=>logDebug('focus changed: $value'),
                            onKeyEvent: (node,event)=>handleKeyEvent(node,event),
                      child: Container(decoration: BoxDecoration(color:Colors.amber[100], border: const Border.symmetric(),),
                    
                      child: 
                        !_filesLoaded()?_loadFilesFirstNotLoaded(context) :
                        MattGameLevelWidget(assets:mattAssets, 
                                     file: selectedFile, 
                                     grid: grid,
                                     tileTapped: _tileTapped,
                                     ),
                                )))
                          
                ],
                ),          
            ],           
            ), // This trailing comma makes auto-formatting nicer for build methods.          )
        ),
        );
    
  }

  Future <bool> loadFileData(bool first) async {
    // if (first) 
    //   {await gameFiles.loadHallOfFameFile();}
    try {
      bool result = await gameFiles.loadMatFileData(matDirectory);
      if (!result) {return false; }
      // MattFile?  newFile = gameFiles.getMatFile().first;
        
      logDebug('resultaat loadFileData: ');
      for (MattFile entry in gameFiles.getMatFile()) {       
        logDebug('file: $entry');
        // MattLevelHallOfFameEntry? maxLevelEntry = solvedGameLevels.highestLevel(entry.title, player);
        // int maxLevel = maxLevelEntry != null ? maxLevelEntry.level : 1;
        int maxLevel = 1;
        for (MattLevel level in entry.levels) {
          level.accessible = level.level <= maxLevel;
        }
      }
      if (gameFiles.getNrMattFiles() > 0) {
        newFile ??= gameFiles.getMatFile().first;
        return true;
      }
      return false;
    }
    on Exception catch(e) {
      logDebug('Exception in loadFileData: $e');
      return false;
    }
  }

  // void loadSolutions(MattFile? file) async {
  //   solutions.clear();
  //   if (file == null) {return;}
  //   String filename = file.filename;
  //   solutions.parseFile(pathWithExtension(filename,'.sol'));
  // }

  Future loadHallOfFame() async {
    solvedGameLevels.clear();
    solvedGameLevels.parseFile(p.join('.', 'sol', 'mrmatt.hof'));
  }

  void callBackFile(MattFile? file) {
    newFile = file;
    // loadSolutions(newFile);
    logDebug('file changed: $file');
  }
  Widget _loadFilesFirstNotLoaded(BuildContext context) {
    assert (!_filesLoaded());
    return FutureBuilder<bool>(future: loadFileData(true), 
            builder:(context, snapshot) {
              if (snapshot.hasData) {
                return 
            Center( child: 
              Column(                          
                children: [const SizedBox(height:20), 
                          MattSelectFileTile(files:gameFiles.currentMatFiles,fileChanged: callBackFile),
                          const SizedBox(height:16),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                          children:[MattDialogButton(onPressed: () {
                                    startNewGame(newFile!);
                              },
                              label: "load",
                              icon: const Icon(Icons.check),
                              ),
                              const SizedBox(width: 20),
                          ])
                          ]               
                ),
                );
              }
              else {
                return  const Center(
                        child: CircularProgressIndicator(),);
              }
            },);
  }

  void loadFile(BuildContext context) async {
    if (gameFiles.currentMatFiles.isEmpty) {
      await loadFileData(false);
    }
    if (gameFiles.currentMatFiles.isEmpty) {
      if (context.mounted) {
        showMessageDialog(context,'No files found...'); 
      }
      return;
    }
    if (context.mounted) {
      MattFile? newFile = await selectFileFromDialog(context, gameFiles.currentMatFiles, selectedFile);
      if (newFile == null) {return;}
      startNewGame(newFile);
    }
  }
  void _selectLevel(int level) {
    setState( () {currentLevel = level;
                  _restartGameCheck('Abandon current level?');
                  } );          
  }

  void startNewGame(MattFile? newFile) {
    int newLevel = 0;
    if (newFile == null) {return;}
    MattGame newGame = MattGame(newFile.levels[newLevel].grid, level: newLevel, game: newFile.title);
    stopwatch.reset();
    stopwatch.start();
    setState(() {
      selectedFile=newFile;
      currentLevel = newLevel;
      game=newGame;      
    });
  }
  void _moveLeft() {
    _gameMove(Move.left);
  }
  void _moveRight() {
    _gameMove(Move.right);
  }
  void _moveUp() {
    _gameMove(Move.up);
  }
  void _moveDown() {
    _gameMove(Move.down);
  }
  Future<void> _gameMove (Move move, [int repeat = 0]) async {
    if (game == null) {return;}    
    if (!game!.canMove(move)) {       
      logDebug('Uh-oh: can not perform move $move');
      return; } 
    MoveResult result = MoveResult.invalid;
    setState(() {
      result = game!.performMove(move, repeat);
      GameSnapshot? lastSnapshot = game!.lastSnapshot;
      _counter+= lastSnapshot != null? lastSnapshot.nrMoves : 0;
    });
    switch  (result) {
      case MoveResult.finish: { _winner();}
      case MoveResult.stuck: { _ohNo(false);}
      case MoveResult.killed: {_ohNo(true);}
    default:
  }
  }
  void _tileTapped(Tile tile){
    if (game == null || (tile.row != game!.mrMatt.row && tile.col != game!.mrMatt.col)) {return;}    
    _moveToTarget(tile);
  }
  void _moveToTarget(Tile tile) {
    if (game == null || (tile.row != game!.mrMatt.row && tile.col != game!.mrMatt.col)) {return;}    
    if (tile.row == game!.mrMatt.row) {
      int delta = tile.col - game!.mrMatt.col;
      _gameMove(delta > 0 ? Move.right: Move.left, delta.abs()-1);
    }
    else if (tile.col == game!.mrMatt.col) {
      int delta = tile.row - game!.mrMatt.row;
      _gameMove(delta > 0 ? Move.down: Move.up, delta.abs()-1);
    }
  }
  void _undoMove(){
    if (game==null || _counter == 0) {return;}      
    setState(() {      
      _counter -= game!.undoLast();
      if (!stopwatch.isRunning) {stopwatch.start();}
    });
  }

  Future<void> _restartGameCheck([String? message]) async {
    if (game==null || _counter == 0) {return;}
    bool confirm = message != null ? await askConfirm(context, message) : true;
    if (confirm) {setState(() {    
          stopwatch.reset();         
          int newLevel = currentLevel??0;
          game = MattGame(selectedFile.levels[newLevel].grid, level: newLevel, game: selectedFile.title); 
          _counter = 0;
          stopwatch.start();
        });
        }

  }
  Future <void> _restartGame([bool check=true]) async {
    return _restartGameCheck(check ? "Really start again?" : null);
  }

  void _repeatMove(Move move) async {
    int nrTimes = 0;
    switch (move){
      case Move.left: nrTimes = -game!.mrMatt.col;
      case Move.right: nrTimes = GridConst.mattWidth-game!.mrMatt.col+1;
      case Move.up: nrTimes = -game!.mrMatt.row;
      case Move.down: nrTimes = GridConst.mattHeight-game!.mrMatt.row+1;
      default: return;
    }
    await _gameMove(move, nrTimes.abs());
  }
  void _ohNo(bool killed) {
    setState(() {stopwatch.stop();});
    showMessageDialog(context, killed? 
            "Oh no, you've killed Mr. Matt..." :
            "Oh no, Mr. Matt can not move any more. You lost!");
  }
  void _winner() async {
    setState(() {stopwatch.stop();});
    String format = stopwatch.hours > 0 ? 'hh:mm:ss':'mm:ss';    
    bool gameSolved = currentLevel! == selectedFile.nrLevels - 1;
    showMessageDialog(
      context, 'You have completed ${gameSolved? "the whole game" : "this level"} in $_counter moves. Super!\nElapsed time: ($format) ${stopwatch.elapsedTime()}');
    if (!gameSolved) {
      selectedFile.levels[currentLevel!+1].accessible = true;
      setState(() { _selectLevel(currentLevel!+1);});
    }
  }
  void _loader() {
    loadFile(context);
  }
  void _playback() async {
    if (!_gameRunning())
    {return;}
    Moves moves = game!.getMoves();
    await _restartGame(false);
    for (MoveRecord move in moves.moves) {
      await _gameMove(move.move, move.repeat);      
    }
  }
  
}
