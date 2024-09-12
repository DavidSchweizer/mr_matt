import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mr_matt/game/matt_sol.dart';

import 'game/matt_file.dart';
import 'game/matt_game.dart';
import 'game/matt_grid.dart';
import 'game/matt_level.dart';
import 'log.dart';
import 'matt_select_file.dart';
import 'matt_widgets.dart';
import 'widgets/dialogs.dart';
import 'widgets/stopwatch.dart';

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
  int _counter = 0;
  final MattAssets mattAssets = MattAssets();
  MattFiles fileData = MattFiles();
  SecondsStopwatch stopwatch = SecondsStopwatch();
  LogicalKeyboardKey? lastKeyDown;
  MattFile selectedFile=MattFile();
  MattGame? game;
  MattFile? newFile;
  int? currentLevel;

  bool _fileLoaded() =>selectedFile.isNotEmpty();
  bool _filesLoaded() => !fileData.isEmpty();
  bool _levelSelected() =>currentLevel!=null;

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
          title: Text('Mr. Matt | ${_getTitle()}'),
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
            IconButton(
                    onPressed: _moveLeft,
                    icon: const Icon(
                      Icons.keyboard_arrow_left,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            IconButton(
                    onPressed: _moveUp,
                    icon: const Icon(
                      Icons.keyboard_arrow_up,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            IconButton(
                    onPressed: _moveDown,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            IconButton(
                    onPressed: _moveRight,
                    icon: const Icon(
                      Icons.keyboard_arrow_right,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),                      
            IconButton(
                    onPressed: _restartGame,
                    icon: const Icon(
                      Icons.restart_alt,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            IconButton(
                    onPressed: _undoMove,
                    icon: const Icon(
                      Icons.undo,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
            IconButton(
                    onPressed: _loader,
                    icon: const Icon(
                      Icons.folder_open,
                      size: 30,
                      color: Colors.white,
                    )),
                const SizedBox(
                  width: 10,
                ),
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

  Future <bool> loadFileData() async {
    int nBefore = fileData.nrFiles();
    await fileData.readDirectory('mat');
    newFile = fileData.mattFiles[0];
    logDebug('resultaat loadFileData: ');
    for (MattFile entry in fileData.mattFiles) {
      logDebug('file: $entry');
    }
    return fileData.nrFiles() > nBefore;
  }

  void callBackFile(MattFile? file) {
    newFile = file;
    logDebug('file changed: $file');
  }

  Widget _loadFilesFirstNotLoaded(BuildContext context) {
    assert (!_filesLoaded());
    return FutureBuilder<bool>(future: loadFileData(), 
            builder:(context, snapshot) {
              if (snapshot.hasData) {
                return 
            Center( child: 
              Column(                          
                children: [const SizedBox(height:20), 
                          MattSelectFileTile(files:fileData,fileChanged: callBackFile),
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
    if (fileData.mattFiles.isEmpty) {
      await loadFileData();
    }
    if (fileData.mattFiles.isEmpty) {
      if (context.mounted) {
        showMessageDialog(context,'No files found...'); 
      }
      return;
    }
    if (context.mounted) {
      MattFile? newFile = await selectFileFromDialog(context, fileData, selectedFile);
      if (newFile == null) {return;}
      startNewGame(newFile);
    }
  }
  void _selectLevel(int level) {
    setState( () {currentLevel = level;
                  _restartGameCheck('Abandon current level?');
                  } );          
  }

  void startNewGame(MattFile newFile) {
    int newLevel = 0;
    MattGame newGame = MattGame(newFile.levels[newLevel].grid);
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
  void _gameMove (Move move, [int repeat = 0]) {
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

  void _restartGameCheck([String? message]) async {
    if (game==null || _counter == 0) {return;}
    bool confirm = message != null ? await askConfirm(context, message) : true;
    if (confirm) {setState(() {    
          stopwatch.reset();         
          game = MattGame(selectedFile.levels[currentLevel??0].grid); 
          _counter = 0;
          stopwatch.start();
        });
        }

  }

  void _restartGame() async {
    _restartGameCheck("Really start again?");
    MattSolutionFile testing = MattSolutionFile();
    testing.parseFile('d:/mrmatt/chicago_2.sol');
  }

  void _repeatMove(Move move) {
    int nrTimes = 0;
    switch (move){
      case Move.left: nrTimes = -game!.mrMatt.col;
      case Move.right: nrTimes = GridConst.mattWidth-game!.mrMatt.col+1;
      case Move.up: nrTimes = -game!.mrMatt.row;
      case Move.down: nrTimes = GridConst.mattHeight-game!.mrMatt.row+1;
      default: return;
    }
    return _gameMove(move, nrTimes.abs());
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
}
