// FIRST: consolidate versions!
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
import 'game/matt_sol.dart';
import 'images.dart';
import 'matt_select_file.dart';
import 'matt_select_style.dart';
import 'matt_widgets.dart';
import 'utils/log.dart';
import 'widgets/dialogs.dart';
import 'widgets/stopwatch.dart';
import 'package:path/path.dart' as p;

void main() {
  initLogging();
  runApp(const MrMattApp());
}

enum DrawerDestination {openGame, selectLevel, restart, saveBookmark,restoreBookmark, 
          undoLast, replay, showSolution, selectStyle }

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
  int _moveCounter = 0;
  TileImageType _imageType = MTC.defaultImageType;
  TileImageType get imageType =>_imageType;
  set imageType(TileImageType value) {
    _imageType = value;
    assetImages.imageType = value;
    // (images.imageType is set in the widget during Future loading)
  }
  final MattTileImages images = MattTileImages();
  final MattAssetImages assetImages = MattAssetImages();

  SecondsStopwatch stopwatch = SecondsStopwatch();
  LogicalKeyboardKey? lastKeyDown;
  MattFile selectedFile=MattFile();
  MattGame? game;
  Grid? grid;

  bool isLost = false;

  MattFile? newFile;
  int? currentLevel;
  String player = "Mr David #1899";
  
  final Duration timerDelay = Durations.short1;
  Queue<Move> movesQueue = Queue<Move>();
  TileMoves? tileMoves = TileMoves();

  Timer? playBackTimer;
  Timer? movesTimer;

  MediaQueryData? queryData;
  double? _toolbarHeight;
  double? _mainWidth;

  Map<int,void Function()> drawerFunctions = {};

  void _pushMove(Move move) => movesQueue.addLast(move);
  void _pushMoveRecord(MoveRecord moveRecord) {
    for (int i = moveRecord.repeat; i>=0;i--) {
      _pushMove(moveRecord.move);}
  }
  Move _popMove() => movesQueue.removeFirst();
  void playBackOne() {
    _gameMove(_popMove());
  }
  
  GameFiles gameFiles = GameFiles();
  
  bool get isFileLoaded =>isFilesLoaded&&selectedFile.isNotEmpty();
  bool get isFilesLoaded=> gameFiles.currentMatFiles.isNotEmpty;
  bool get isLevelSelected =>isFileLoaded&&currentLevel!=null;
  bool get isGameSelected =>game!=null;
  bool get isGameStart=>isGameSelected && _moveCounter == 0;
  bool get isGameStarted=>isGameSelected && _moveCounter > 0;
  bool get hasBookmarks=>isGameSelected && game!.hasBookmarks;
  bool get hasKnownSolution=>isGameSelected&&isLevelSelected&&gameFiles.hasSolution(selectedFile, currentLevel!);

  bool playedSolution = false;

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
    Map<DrawerDestination,Map<String,dynamic>> destinations = 
    {DrawerDestination.openGame:
      {'label': 'Load game', 'icon': Icons.folder_open, 'enabled':isFilesLoaded, 'function': _loader },
     DrawerDestination.selectLevel:
      {'label': 'Select level', 'icon': Icons.format_list_numbered, 'enabled':true, 'function': _levelSelect, },
     DrawerDestination.restart:
      {'label': 'Restart game', 'icon': Icons.restart_alt, 'enabled':isGameStarted, 'function': _restartGame2,'divider': true },
     DrawerDestination.saveBookmark:
      {'label': 'Save bookmark', 'icon': Icons.bookmark_add, 'enabled':isGameStarted, 'function': _saveBookmark  },
     DrawerDestination.restoreBookmark:
      {'label': 'Restore bookmark', 'icon': Icons.bookmark_remove, 'enabled':hasBookmarks, 'function': _restoreBookmark  },
     DrawerDestination.undoLast:
      {'label': 'Undo last move (ctrl-Z)', 'icon': Icons.undo, 'enabled':isGameStarted, 'function': _undoMove, 'divider': true  },
     DrawerDestination.replay:
      {'label': 'Replay moves', 'icon': Icons.play_arrow, 'enabled':isGameStarted, 'function': _setupPlayback },
      DrawerDestination.showSolution:
      {'label': 'Show solution', 'icon': Icons.slideshow, 'enabled':hasKnownSolution, 'function': _playSolution, 'divider': true },
     DrawerDestination.selectStyle:
      {'label': 'Select style', 'icon': Icons.style, 'enabled':true, 'function': _selectStyle },
    };
    
    Image? mrMattImage = assetImages.getImage(isLost? TileType.loser: TileType.mrMatt);
    Widget headlineWidget = Text('Game menu',
              style: Theme.of(context).textTheme.headlineSmall);
    List<Widget> result = [Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
              child: mrMattImage != null ? Row(children: 
                            [Padding(padding: const EdgeInsetsDirectional.all(8), child : CircleAvatar(backgroundImage: mrMattImage.image)), 
                                headlineWidget]):
                                headlineWidget
            ),
      const Divider(),
    ];
    int index = 0;
    for (DrawerDestination destination in DrawerDestination.values) {
      Map<String,dynamic> entry = destinations[destination]!;
      result.add(
      NavigationDrawerDestination(key: ValueKey(destination), 
                icon: Icon(entry['icon']), label: Text(entry['label']), enabled:entry['enabled']));
      drawerFunctions[index] = entry['function'];
      index++;
      if (entry['divider']??false) {
        result.add(const Divider(height: 20, thickness: 1),);
      }
    }
    return result;
  }
  void _drawerSelected(int index) {
    void Function()? execute = drawerFunctions[index];
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
    _toolbarHeight = totalHeight * 0.15;
    double maxHeight = totalHeight * 0.85 - 12;
    _mainWidth = min(totalWidth-8, maxHeight * GC.aspectRatio);
    logDebug('changed deps: width: $totalWidth, height: $totalHeight, \ntoolbar: $_toolbarHeight');
    logDebug('main width: $_mainWidth expected height: ${_mainWidth!/GC.aspectRatio} avail: $maxHeight');
    super.didChangeDependencies();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Row(
            children: [
              Text('Mr. Matt ($player) | ${_getTitle()}'),
              const VerticalDivider(width: 40),
              Text('moves: $_moveCounter'),
              const VerticalDivider(width: 40),
              const Text('time: '),
              StopwatchWidget(stopwatch: stopwatch)
            ],
          ),// | moves: $_moveCounter | time: ${stopwatch.elapsedTime()}'),
          toolbarHeight: _toolbarHeight,
        ),
        drawer: NavigationDrawer(onDestinationSelected: _drawerSelected,
              backgroundColor:Colors.amber[100],
          children: _buildDrawerDestinations(context)),
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
                      child: 
                        !isFileLoaded ?
                        _loadFilesFirstNotLoaded(context) :
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
    playedSolution = false;
    setState(() {
      _moveCounter = 0;
      selectedFile=mattFile;
      currentLevel = level;
    });
  }
  void startNewGame(MattFile? newFile) {
    if (newFile != null) {
      _startGame(newFile, newFile.highestLevel());
    }
  }
  void _checkPlaybackMove() async {
    if (tileMoves == null || tileMoves!.isEmpty) {
      return;
    }
    else {
      logDebug('moving tiles {${nowString('HH:mm:ss.S')}} (${tileMoves!.length})');
      TileMove tileMove = tileMoves!.pop()!;
      if (tileMove.tileTypeEnd == TileType.mrMatt) {
        logDebug('... moving MrMatt ...');
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
  Future<void> _gameMove (Move move, [int repeat = 0]) async {
    if (!isGameSelected) {return; }    
    if (!game!.canMove(move)) {       
      logDebug('Uh-oh: can not perform move $move');
      return; 
    } 
    MoveResult? result;
    scheduleMicrotask(() async {result = await game!.performMove(move, repeat); _afterMove(result??MoveResult.invalid);});
  }
  void _levelSelect() async {
    int? newLevel = await selectLevelFromDialog(context, selectedFile, currentLevel??0);
    if (newLevel != null)
      {_selectLevel(newLevel);}    
  }
  
  void _selectStyle() async {
    TileImageType currentImageType = imageType;
    TileImageType? newStyle = await selectStyleFromDialog(context, currentImageType);
    if (newStyle != null && newStyle != currentImageType)
      { await _setStyle(newStyle);}
  }

  Future <void> _setStyle(TileImageType newStyle) async {
    imageType = newStyle; 
    setState((){});
  }
  void _afterMove(MoveResult result) {
    setState(() {
      GameSnapshot? lastSnapshot = game!.lastSnapshot;
      _moveCounter+= lastSnapshot != null? lastSnapshot.nrMoves : 0;
    });
    switch  (result) {
      case MoveResult.finish: { _winner(!playedSolution);}
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
         (restoreLast && _moveCounter==0) || 
         (!restoreLast && !game!.hasBookmarks)) {return;}      
    _moveCounter = restoreLast ? game!.undoLast() : game!.restoreBookmark();
    setState(() {      
      movesQueue.clear();
      tileMoves!.clear();
      grid = Grid.copy(game!.grid);
      if (!stopwatch.isRunning) {stopwatch.start();}
    });

  }
  void _undoMove(){
    isLost = false;
    _setSnapshot(true);
  }
  void __restart(){
    _haltGame();
    setState(() {    
          stopwatch.reset();         
          int newLevel = currentLevel??0;
          _initGame(MattGame(selectedFile.levels[newLevel].grid, level: newLevel, title: selectedFile.title, callback:_checkPlaybackMove));
          _moveCounter = 0;
          isLost = false;
          stopwatch.start();});
  }
  Future<void> _restartGameCheck([String? message]) async {
    if (!isGameSelected ) {return;}
    bool confirm = message != null ? await askConfirm(context, message) : true;
    if (confirm) {__restart();}
  }
  Future <void> _restartGame([bool check=true]) async {
    return await _restartGameCheck(check ? "Really start again?" : null);
  }
  void _restartGame2() async {
    await _restartGame(isGameStarted);
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
    isLost = true;
    showMessageDialog(context, killed? 
            "Oh no, you've killed Mr. Matt..." :
            "Oh no, Mr. Matt can not move any more. You lost!");
  }
  void _winner(bool played) async {
    _haltGame();
    isLost = false;
    assert (game!.levelFinished == true); 
    String format = stopwatch.hours > 0 ? 'hh:mm:ss':'mm:ss';   
    await gameFiles.updateSolution(gameFiles.allSolutionsFile, player, game!, true);
    bool gameSolved = currentLevel! == selectedFile.nrLevels - 1;
    if (mounted) {
        String msg = played ? 'You have completed this level in $_moveCounter moves. Super!\nElapsed time: ($format) ${stopwatch.elapsedTime()}' :
                              'This solution needed $_moveCounter moves. Can you do better?';
      if (gameSolved && played) {
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
  }

  void _playSolution() async {
    MattLevelMoves? levelMoves = gameFiles.findSolution(selectedFile, currentLevel!);
    if (levelMoves == null) {return;}
    playedSolution = true;
    await __setupPlayback(levelMoves.moves);
  }

  Future<void> __setupPlayback(Moves moves) async {
    setState(() {_restartGame(false);});
    _playback(moves);
  }

  Future<void> _setupPlayback() async {
    if (!isGameStarted)
    {return;}
    __setupPlayback(game!.getMoves());
  }
  void _playbackCheck(Timer timer) {
    playBackOne(); 
  }
  void _saveBookmark() {
    if (isGameStarted) { game!.saveBookmark();}
  }
  void _restoreBookmark() {
    if (isGameStarted && game!.hasBookmarks){
      _setSnapshot(false);
    }
  }
}


