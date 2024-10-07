import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mr_matt/game/game_files.dart';
import 'package:mr_matt/widgets/buttons.dart';
import 'game/matt_file.dart';
import 'game/matt_game.dart';
import 'game/matt_grid.dart';
import 'game/matt_level.dart';
import 'images.dart';
import 'matt_select_file.dart';
import 'matt_widgets.dart';
import 'utils/log.dart';
import 'widgets/dialogs.dart';
import 'widgets/stopwatch.dart';
import 'package:path/path.dart' as p;

void main() {
  initLogging();
  runApp(const MrMattApp());
  // closeLogging();
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
  int _playBackCount=0;
  final String matDirectory = p.canonicalize('mat');

  int _counter = 0;
  // final MattAssets mattAssets = MattAssets();
  TileImageType imageType = MTC.defaultImageType;
  final MattTileImages images = MattTileImages();
  // MattFiles fileData = MattFiles();
  SecondsStopwatch stopwatch = SecondsStopwatch();
  LogicalKeyboardKey? lastKeyDown;
  MattFile selectedFile=MattFile();
  MattGame? game;
  Grid? grid;

  MattFile? newFile;
  int? currentLevel;
  String player = "Mr David #1899";
  
  final Duration timerDelay = Durations.short1;
  Queue<Move> movesQueue = Queue<Move>();
  // TileMoves tileMoves = TileMoves();
  TileMoves? tileMoves = TileMoves();

  Timer? playBackTimer;
  Timer? movesTimer;

  MediaQueryData? queryData;
  double? _toolbarHeight;
  double? _mainWidth;
  double? _bottomBarHeight;

  void _pushMove(Move move) => movesQueue.addLast(move);
  void _pushMoveRecord(MoveRecord moveRecord) {
    for (int i = moveRecord.repeat; i>=0;i--) {
      _pushMove(moveRecord.move);}
  }
  Move _popMove() => movesQueue.removeFirst();
  // Future<MoveResult> playBackOne() async {
  void playBackOne() {
    // MoveResult result = ;
    _gameMove(_popMove());
  }
  
  GameFiles gameFiles = GameFiles();
  
  bool get isFileLoaded =>isFilesLoaded&&selectedFile.isNotEmpty();
  bool get isFilesLoaded=> gameFiles.currentMatFiles.isNotEmpty;
  bool get isLevelSelected =>isFileLoaded&&currentLevel!=null;
  bool get isGameSelected =>game!=null;
  bool get isGameStart=>isGameSelected && _counter == 0;
  bool get isGameStarted=>isGameSelected && _counter > 0;
  bool get hasBookmarks=>isGameSelected && game!.hasBookmarks;

  MattLevel? getLevel() {
    if (isLevelSelected){
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
      case LogicalKeyboardKey.arrowLeft: _pushMove(Move.left);
      case LogicalKeyboardKey.arrowRight: _pushMove(Move.right);
      case LogicalKeyboardKey.arrowUp: _pushMove(Move.up);
      case LogicalKeyboardKey.arrowDown: _pushMove(Move.down);
      case LogicalKeyboardKey.keyA: _pushMove(Move.left);
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
    if (isLevelSelected){
      return '${getLevel()!.title} (level ${(currentLevel??0)+1})';
    }
    else { return "no level selected";}
  }
  String _getTitle() {
    if (isFileLoaded) {
      return '${selectedFile.title} - ${_getLevelTitle()}';
    }
    else { return "no file loaded: Load a file first!";}
  }

  @override 
  void initState() {
    super.initState();
    playBackTimer = Timer.periodic(timerDelay, 
                              (timer) {if (movesQueue.isNotEmpty) {_playbackCheck(timer);}});
    movesTimer = Timer.periodic(const Duration(milliseconds:5), (timer) {_playbackMove(timer);});
  } 
  List<Widget> _buildDrawerDestinations(BuildContext context) {
    return [    
      Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text('Game menu',
              style: Theme.of(context).textTheme.titleSmall,),
            ),
      const Divider(),
      NavigationDrawerDestination(icon: const Icon(Icons.folder_open), label: const Text('Load game'), enabled:isFilesLoaded),
      const VerticalDivider(width: 60, thickness: 4, color: Colors.black87),
      NavigationDrawerDestination(icon: const Icon(Icons.bookmark_add), label: const Text('Save bookmark'), enabled: isGameStarted),
      NavigationDrawerDestination(icon: const Icon(Icons.bookmark_remove), label: const Text('Restore bookmark'), enabled: hasBookmarks),
      NavigationDrawerDestination(icon: const Icon(Icons.undo), label: const Text('Undo last move (ctrl-Z)'), enabled: isGameStarted),
      NavigationDrawerDestination(icon: const Icon(Icons.play_arrow), label: const Text('Replay moves'), enabled: isGameStarted),
    ];
  }

  void _drawerSelected(int index) {
    Map<int,void Function()> destinations = 
      {0: _loader, 
      1: _saveBookmark,
      2: _restoreBookmark,
      3: _undoMove,
      4: _setupPlayback,
      };
    logDebug('selected $index');
    void Function()? execute = destinations[index];
    if (execute != null) {
      Navigator.pop(context); 
      execute();
    }
  }

  @override
  void didChangeDependencies() {
    queryData = MediaQuery.of(context);
    double totalHeight = queryData!.size.height;
    double totalWidth = queryData!.size.width;
    _toolbarHeight = totalHeight * 0.1;
    _mainWidth = min(totalWidth-8, (totalHeight * 0.8-12) * GC.aspectRatio);
    _bottomBarHeight = totalHeight * 0.1;
    logDebug('changed deps: width: $totalWidth, height: $totalHeight, \ntoolbar: $_toolbarHeight, bottombar: $_bottomBarHeight');
    logDebug('main width: $_mainWidth expected height: ${_mainWidth!/GC.aspectRatio} avail: ${totalHeight * 0.8} ');
    super.didChangeDependencies();
  }
  @override
  Widget build(BuildContext context) {
    logDebug('BBB: start build (main) {${nowString('HH:mm:ss.S')}}');
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('Mr. Matt ($player) | ${_getTitle()}'),
          toolbarHeight: _toolbarHeight,
        ),
        drawer: NavigationDrawer(onDestinationSelected: _drawerSelected,
              backgroundColor:Colors.amber[100],
          children: _buildDrawerDestinations(context)),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.inversePrimary,
          elevation: 10,
          height: _bottomBarHeight! ,//* queryData.size.height,
          child:
          Row(children: [
            Row(
              children: [
                const Text("time:"),
                StopwatchWidget(stopwatch: stopwatch),
              ],
            ),
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
            Text('moves: $_counter'),
            
            // const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
            
            // MattAppBarButton(
            //         onPressed: _moveLeft,
            //         iconData: Icons.keyboard_arrow_left),
            // MattAppBarButton(
            //         onPressed: _moveUp,
            //           iconData: Icons.keyboard_arrow_up),
            // MattAppBarButton(
            //         onPressed: _moveDown,
            //         iconData: Icons.keyboard_arrow_down),
            // MattAppBarButton(
            //         onPressed: _moveRight,
            //         iconData: Icons.keyboard_arrow_right),
            // const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),                      
            // MattAppBarButton(
            //         onPressed: _restartGame,
            //         iconData: Icons.restart_alt),
            // MattAppBarButton(
            //         onPressed: _undoMove,
            //         iconData: Icons.undo),
            // MattAppBarButton(
            //         onPressed: _loader,
            //         iconData: Icons.folder_open),
            // const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
            //     const SizedBox(
            //       width: 10,
            //     ),
            // MattAppBarButton(
            //         onPressed: () async {_saveGame();},
            //         iconData: Icons.download),
            // MattAppBarButton(
            //         onPressed: () async {_loadGame();},
            //         iconData: Icons.upload),
            // const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
            //     const SizedBox(
            //       width: 10,
            //     ),                
            // MattAppBarButton(
            //         onPressed: () async {_setupPlayback();},
            //         iconData: Icons.playlist_play),
            // // MattAppBarButton(
            // //         onPressed: () async {wipwap();},
            // //         iconData: Icons.auto_awesome_mosaic),
                    
            const VerticalDivider(color: Colors.black38, width: 10, thickness: 3, indent: 5, endIndent: 5),
                const SizedBox(
                  width: 10,
                ),
            MattLevelSelector(file: selectedFile, levelSelected: _selectLevel, selected:currentLevel),

            Text('Height: ${queryData?.size.height} width: ${queryData?.size.width}'),
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
                SizedBox(width: _mainWidth!, height: _mainWidth!/GC.aspectRatio,
                child: 
                  Focus(onFocusChange: (bool value)=>logDebug('focus changed: $value'),
                            onKeyEvent: (node,event)=>handleKeyEvent(node,event),
                      // child: Container(decoration: BoxDecoration(color:Colors.green[100], border: const Border.symmetric(),),
                    
                      child: 
                        !isFileLoaded ?_loadFilesFirstNotLoaded(context) :
                
                        MattGameLevelWidget(images:images, 
                                      imageType: imageType,
                                      width: _mainWidth!,
                                     file: selectedFile, 
                                     grid: grid,
                                     onTapUpCallback: _tileTappedCallBack,
                                     ),
                                ))
                          
                ],
                ),          
            ],           
            ), // This trailing comma makes auto-formatting nicer for build methods.          )
        ),
        );
    
  }

  Future <bool> loadFileData(bool first) async {
    try {
      bool result = await gameFiles.loadMatFileData(matDirectory);
      if (!result) {return false; }       
      if (first) {
        await gameFiles.loadSolutionFile(gameFiles.allSolutionsFile);
      }
      for (MattFile entry in gameFiles.getMatFile()) {               
        int maxLevel = 1 + gameFiles.highestSolutionLevel(gameFiles.allSolutionsFile, player, entry.title);
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

  void callBackFile(MattFile? file) {
    newFile = file;
    // loadSolutions(newFile);
    logDebug('file changed: $file');
  }
  Widget _loadFilesFirstNotLoaded(BuildContext context) {
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
  void _selectLevel(int level) async {
    if (game!.isNotEmpty && level != currentLevel && !game!.levelFinished) {
      if (! await askConfirm(context, 'Abandon current level?')) {
        return;
      }
    }    
    _startGame(selectedFile, level);
  }

  void _initGame(MattGame newGame) {
      game=newGame; 
      grid=Grid.copy(game!.grid);
      tileMoves = game!.tileMoves;
      tileMoves!.clear();
      movesQueue.clear();
  }

  void _startGame(MattFile? mattFile, int level) {
    if (mattFile == null || level > mattFile.highestLevel()) {return;}
    grid = null;
    _initGame(MattGame(mattFile.levels[level].grid, level: level, title: mattFile.title, callback: _checkPlaybackMove));
    stopwatch.reset();
    stopwatch.start();
    setState(() {
      _counter = 0;
      selectedFile=mattFile;
      currentLevel = level;
    });
  }
  void startNewGame(MattFile? newFile) {
    if (newFile != null) {
      _startGame(newFile, newFile.highestLevel());
    }
  }
  // void _moveLeft() {
  //   _gameMove(Move.left);
  // }
  // void _moveRight() {
  //   _gameMove(Move.right);
  // }
  // void _moveUp() {
  //   _gameMove(Move.up);
  // }
  // void _moveDown() {
  //   _gameMove(Move.down);
  // }
  
  void _checkPlaybackMove() async {
    if (tileMoves == null || tileMoves!.isEmpty) {
      // logDebug('no tile moves available {${nowString()}}');
      return;
    }
    else {
      logDebug('moving tiles {${nowString('HH:mm:ss.S')}} (${tileMoves!.length})');
      TileMove tileMove = tileMoves!.pop()!;
      if (tileMove.tileTypeEnd == TileType.mrMatt) {
        logDebug('... moving MrMatt ...');
        // await Future.delayed(Durations.long4);
      }
      setState(() {
        grid!.setCellType(tileMove.rowStart,tileMove.colStart, TileType.empty);
        grid!.setCellType(tileMove.rowEnd,tileMove.colEnd, tileMove.tileTypeEnd);
      });
      logDebug('end moving tiles {${nowString('HH:mm:ss.S')}}');
      await Future.delayed(Durations.long1);
    }
  }

  void _playbackMove(Timer timer) async {
    _checkPlaybackMove();
  }
  
  //Future<MoveResult> _gameMove (Move move, [int repeat = 0]) async {
  Future<void> _gameMove (Move move, [int repeat = 0]) async {
    if (!isGameSelected) {return; }    
    if (!game!.canMove(move)) {       
      logDebug('Uh-oh: can not perform move $move');
      return; 
    } 
    // result = await game!.performMove(move, repeat);
    // Future <MoveResult> result;
    MoveResult? result;
    logDebug('///scheduliting $move repeat:$repeat {${nowString('HH:mm:ss.S')}}');
    scheduleMicrotask(() async {result = await game!.performMove(move, repeat); _afterMove(result??MoveResult.invalid);});
    logDebug('///scheduled {${nowString('HH:mm:ss.S')}}');
    // tileMoves.add(game!.tileMoves);
    // 
    // setState(() {
    //   GameSnapshot? lastSnapshot = game!.lastSnapshot;
    //   _counter+= lastSnapshot != null? lastSnapshot.nrMoves : 0;
    // });
    // switch  (result) {
    //   case MoveResult.finish: { _winner();}
    //   case MoveResult.stuck: { _ohNo(false);}
    //   case MoveResult.killed: {_ohNo(true);}
    // default:
    // }
    // return result??MoveResult.ok;
  }

  void _afterMove(MoveResult result) {
    setState(() {
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

  void _tileTappedCallBack(Tile? tile){
    if (!isGameSelected || tile == null || (tile.row != game!.mrMatt.row && tile.col != game!.mrMatt.col)) {return;}    
    _moveToTarget(tile);
  }
  void _moveToTarget(Tile tile) {
    if (!isGameSelected || (tile.row != game!.mrMatt.row && tile.col != game!.mrMatt.col)) {return;}    
    if (tile.row == game!.mrMatt.row) {
      int delta = tile.col - game!.mrMatt.col;
      _repeatMove(delta > 0 ? Move.right: Move.left, repeat: delta.abs()-1);
    }
    else if (tile.col == game!.mrMatt.col) {
      int delta = tile.row - game!.mrMatt.row;
      _repeatMove(delta > 0 ? Move.down: Move.up, repeat: delta.abs()-1);
    }
  }

  void _setSnapshot(bool restoreLast) {
    if (!isGameSelected ||
         (restoreLast && _counter==0) || 
         (!restoreLast && !game!.hasBookmarks)) {return;}      
    _counter = restoreLast ? game!.undoLast() : game!.restoreBookmark();
    setState(() {      
      movesQueue.clear();
      tileMoves!.clear();
      grid = Grid.copy(game!.grid);
      if (!stopwatch.isRunning) {stopwatch.start();}
    });

  }
  void _undoMove(){
    _setSnapshot(true);
  }
  void __restart(){
    _haltGame();
    setState(() {    
          stopwatch.reset();         
          int newLevel = currentLevel??0;
          _initGame(MattGame(selectedFile.levels[newLevel].grid, level: newLevel, title: selectedFile.title, callback:_checkPlaybackMove));
          _counter = 0;
          stopwatch.start();});
  }
  Future<void> _restartGameCheck([String? message]) async {
    if (!isGameSelected /*|| _counter == 0*/) {return;}
    bool confirm = message != null ? await askConfirm(context, message) : true;
    if (confirm) {__restart();}
  }
  Future <void> _restartGame([bool check=true]) async {
    return await _restartGameCheck(check ? "Really start again?" : null);
  }
  void _repeatMove(Move move, { int? repeat}) async {
    int nrTimes = 0;
    switch (move) {
      case Move.left: nrTimes = repeat ?? -game!.mrMatt.col;
      case Move.right: nrTimes = repeat ?? GC.mattWidth-game!.mrMatt.col+1;
      case Move.up: nrTimes = repeat ??-game!.mrMatt.row;
      case Move.down: nrTimes = repeat ?? GC.mattHeight-game!.mrMatt.row+1;
      default: return;
    }
    _pushMoveRecord(MoveRecord(move:move, repeat:nrTimes.abs()));
  }
  void _haltGame(){
    stopwatch.stop();
    movesQueue.clear();
    // tileMoves.clear();
    setState(() {
    });
  }
  void _ohNo(bool killed) {
    tileMoves!.push(game!.mrMatt.row, game!.mrMatt.col, game!.mrMatt.row, game!.mrMatt.col, TileType.loser);
    _haltGame();
    showMessageDialog(context, killed? 
            "Oh no, you've killed Mr. Matt..." :
            "Oh no, Mr. Matt can not move any more. You lost!");
  }
  void _winner() async {
    _haltGame();
    assert (game!.levelFinished == true); 
    String format = stopwatch.hours > 0 ? 'hh:mm:ss':'mm:ss';   
    await gameFiles.updateSolution(gameFiles.allSolutionsFile, player, game!, true);
    bool gameSolved = currentLevel! == selectedFile.nrLevels - 1;
    if (mounted) {
      String msg = 'You have completed this level in $_counter moves. Super!\nElapsed time: ($format) ${stopwatch.elapsedTime()}';
      if (gameSolved) {
        msg = '$msg\nThis was the last level of this game!';
      }
      await showMessageDialog(context, msg);
      if (!gameSolved) {
        selectedFile.levels[currentLevel!+1].accessible = true;
      }
    }
    setState(() { _selectLevel(currentLevel! + (gameSolved? 0: 1));});    
  }
  void _loader() {
    _haltGame();
    loadFile(context);
  }
  Future<void> _playback(Moves moves) async {
    movesQueue.clear();
    for (MoveRecord moveRecord in moves.moves) {
      _pushMoveRecord(moveRecord);
    }    
    logDebug('END setupPlayback');
  }
  Future<void> _setupPlayback() async {
    logDebug('START setupPlayback');
    if (!isGameStarted)
    {return;}
    setState(() {_restartGame(false);});
    _playback(game!.getMoves());
    logDebug('END setupPlayback');
  }

  void _playbackCheck(Timer timer) {
    logDebug('---- Playback?... ($_playBackCount)');
    // MoveResult result = await playBackOne(); 
    // MoveResult result = playBackOne(); 
    playBackOne(); 
    logDebug('---- END Playback ($_playBackCount)...');
    _playBackCount++;
  }
  void _saveBookmark() {
    if (isGameStarted) { game!.saveBookmark();}
  }
  void _restoreBookmark() {
    if (isGameStarted && game!.hasBookmarks){
      _setSnapshot(false);
    }
  }
  // Future<MattLevelMoves?> _loadSaveData() async {
  //   MattLevelMoves? result;
  //   if (await gameFiles.loadSolutionFile('mr_matt.sav')){
  //     MattSolutionFile? saveGameFile = gameFiles.solutions['mr_matt.sav'];
  //     if (saveGameFile != null) {
  //       result = saveGameFile.findEntry(player, game!.title,currentLevel!);
  //     }
  //   }
  //   return result;
  // }
  // Future<void> _setupLoad() async {
  //   MattLevelMoves? moves = await _loadSaveData();
  //   if (moves != null) {
  //     setState(() {_restartGame(false);});
  //     _playback(moves.moves);
  //   }
  // }  
  // void _loadGame() async {
  //   await _setupLoad();
  //   logDebug('loading');
  // }
  // void wipwap() async {  
  //   int row=random(0,GC.mattHeight);
  //   int col=random(0,GC.mattWidth);
  //   Tile tile = grid!.cell(row,col);
  //   logDebug('wapping [$row,$col]  ($tile)');
  //   setState(() 
  //   { if (tile.isEmpty()) 
  //     {game!.grid.setCell(row,col, Tile(TileType.bomb));}
  //   else 
  //     {game!.grid.setCell(row,col, Tile(TileType.empty));
  //     }
  //   });
  // }
}


