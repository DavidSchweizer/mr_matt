import "dart:collection";
// ignore: unused_import
import "package:flutter/material.dart";
import "package:mr_matt/log.dart";

import "matt_grid.dart";
import "matt_fall.dart";

enum Move  {none, left,up,right,down}
const Map<String,Move> moveFromCode = {'L':Move.left, 'U':Move.up, 'R': Move.right, 'D': Move.down};
const Map<Move,String> moveToCode   = {Move.left: 'L', Move.up:'U', Move.right:'R', Move.down:'D', Move.none: ''};


bool isHorizontalMove(Move move)=>move==Move.left || move==Move.right;
bool isVerticalMove(Move move)=>move==Move.up || move==Move.down;
enum MoveResult {invalid,ok,stuck,killed,finish,} // move is invalid, move OK, MrMatt can't move any more, MrMatt was killed, last apple eaten (Win!)
class MoveRecord {
  late Move move;
  late int repeat;
  late MoveResult? result;
  MoveRecord({required this.move, required this.repeat, this.result});
  int get nrMoves=>repeat+1;
}
class Moves {
  List<MoveRecord> moves = [];
  int _nrMoves = 0;
  void clear(){
    moves.clear();
    _nrMoves = 0;
  }
  int get nrMoves=>_nrMoves;
  void addMove(MoveRecord move) {
    moves.add(move);
    _nrMoves += move.nrMoves;
  }
  @override
  String toString(){
    String result = "";
    for (MoveRecord move in moves){
      result += '[${move.move.name}${move.repeat}]';
    }
    return result;
  }
}
class GameSnapshot {
  late Grid _previousGrid;
  Grid get previousGrid =>_previousGrid;
  late MoveRecord _moveRecord; 
  MoveRecord get moveRecord =>_moveRecord;
  late RowCol? _mrMatt;
  RowCol get mrMatt =>_mrMatt??previousGrid.findMrMatt();
  GameSnapshot(Grid previousGrid, Move move, {MoveResult? result,int? repeat, RowCol? mrMatt}) {
    _previousGrid = previousGrid;
    _moveRecord  = MoveRecord(move:move, repeat:repeat??0, result: result);
    _mrMatt = mrMatt;
  }
  int get nrMoves=>moveRecord.nrMoves;
}

class MattGame {
  late Grid _startGrid; // the original grid
  Grid get startGrid=>_startGrid;

  late Grid _grid; // the current grid
  Grid get grid=>_grid;
  set grid(Grid value)=>_grid=Grid.copy(value);
  
  late int _nrFood; // nr of food (apples)
  int get nrFood=>_nrFood;
  set nrFood(value)=>_nrFood=value;
  bool get isEmpty =>snapshots.isEmpty;
  bool get isNotEmpty =>snapshots.isNotEmpty;
  
  late RowCol mrMatt; // location of MrMatt
  
  late int level;
  late String title;
  bool get levelFinished =>nrFood == 0;

  final TileMoves tileMoves = TileMoves();
  Queue<GameSnapshot> snapshots = Queue();
  final bool _detailedLog = false;

  void _log(String s){ 
    if (_detailedLog) logDebug(s);
  }

  Function()? callback;
  MattGame(Grid grid, {required this.level, required this.title, required this.callback}) {
    _startGrid = grid;
    this.grid = grid;
    nrFood = grid.nrFood();    
    mrMatt=grid.findMrMatt();
  }
  Moves getMoves() {
    Moves moves = Moves();
    for (GameSnapshot snapshot in snapshots) {
      moves.addMove(snapshot.moveRecord);
    }    
    return moves;
  }
  MoveRecord? get lastMove => snapshots.isNotEmpty? snapshots.last.moveRecord:null;
  GameSnapshot? get lastSnapshot => snapshots.isNotEmpty? snapshots.last:null;

  void takeSnapshot(Grid current, Move move, MoveResult result, int repeat, RowCol mrMatt) {
    snapshots.addLast(GameSnapshot(current, move, result: result, repeat: repeat, mrMatt: mrMatt));  
  }

  bool _moveValid(int row,int col) {    
    if (!GridConst.isGridRowCol(row,col)) return false;      

    int rowStep = (row-mrMatt.row).abs(); // should be 0 or 1
    int colStep = (col-mrMatt.col).abs(); // should be 0 or 1
    // steps should be 0 or 1, and both 1 or 0 is not allowed
    return (rowStep <= 1 && colStep <= 1 && rowStep != colStep);
  }
  bool _checkCanMoveObject(int row, int col) {
    // checks whether MrMatt can move an object (bomb, rock, box)
    // only way allowed is moving one (horizontal) step 
    // and only to an empty cell
    assert (row == mrMatt.row);
    assert ((col-mrMatt.col).abs() == 1);
    int nextCol = col + col - mrMatt.col;
    if (!GridConst.isGridCol(nextCol)) {
      _log('---at border');    
      return false;
    }
    Tile nextCell = grid.cell(row, nextCol);
    bool isEmpty = nextCell.isEmpty();
    _log('---next cell $nextCell  (empty: $isEmpty)');    
    return isEmpty;
  }
  bool canMove(Move move) {
    if (_stuffAboveMrMattBlocksVerticalMove(move)) {
      return false;
    }
    RowCol targetLoc = _rolColFromMove(move);
    _log('Start canMove  $move to ($targetLoc)');    
    if (!_moveValid(targetLoc.row,targetLoc.col)) {
      return false;
    }
    // now check the target tile
    Tile target = grid.cell(targetLoc.row,targetLoc.col);
    if (target.isMrMatt()) 
    {
      logDebug('---mrMatt');    
      throw(MrMattException('Multiple MrMatt'));
    }
    else if (target.isWall()) {
      _log('WALL');
      return false;
    }
    else if (target.isConsumable() || target.isEmpty()) 
    {
      _log('---consumable or empty [canMove:TRUE]');          
      return true;
    }
    else if (target.isMovable()) {
        // can only move one item in a row, not up or down
      if (isHorizontalMove(move)) {
        bool result = targetLoc.row == mrMatt.row && _checkCanMoveObject(targetLoc.row, targetLoc.col);
        _log('---movable [canMove: $result]');
        return result;
      }
      else {return false;}
    }
    throw (MrMattException('Unexpected target tile type $target'));
  }
  RowCol _rolColFromMove(Move move){ 
    switch (move) {
      case Move.left: return RowCol(mrMatt.row, mrMatt.col-1);
      case Move.right: return RowCol(mrMatt.row, mrMatt.col+1);
      case Move.up: return RowCol(mrMatt.row-1, mrMatt.col);
      case Move.down: return RowCol(mrMatt.row+1, mrMatt.col);
      case Move.none: return RowCol(mrMatt.row, mrMatt.col);
      }
  }
  void moveMrMatt(int row, int col) {
    if (grid.cell(row,col).isFood()) {
      logDebug('--- hap! ($row,$col)');
      nrFood -= 1;
    }
    int oldRow = mrMatt.row;
    int oldCol = mrMatt.col;
    mrMatt = RowCol(row,col);   
    moveTile(oldRow, oldCol, row, col, TileType.mrMatt);
    // grid.cell(mrMatt.row, mrMatt.col).setEmpty();
    logDebug('Moved mrMatt to $mrMatt {${nowString('HH:mm:ss.S')}}');
  }
  MoveResult _moveObject(int row, int col, Move move, FallHandler handler) {
    assert (isHorizontalMove(move));
    int targetCol = move == Move.left ? col-1 : col+1;
    assert (grid.cell(row,targetCol).isEmpty());
    _log('moving object at [$row,$col] to $targetCol');
    moveTile(row, col, row, targetCol, grid.cell(row,col).tileType);
    MoveResult dropResult = handler.handle(row, targetCol);    
    _log('dropResult: $dropResult');
    return dropResult;
  }
    
  Future<MoveResult> performMove(Move move, [int repeat = 0]) async {
  // MoveResult performMove(Move move, [int repeat = 0]) {
    logDebug('Start perform move {${nowString('HH:mm:ss.S')}} ($move) target ($move) repeat:$repeat');    
    if (!canMove(move)) {
      logDebug('--- invalid move');    
      return MoveResult.invalid;
    }
    FallHandler handler = FallHandler(grid, tileMoves, callback);
    MoveResult result;
    RowCol mrMatt = RowCol(this.mrMatt.row,this.mrMatt.col);  
    Grid startGrid = Grid.copy(grid);
    int performed = 0;
    do {
      result = _performMove(move, handler);
      if (result != MoveResult.invalid)
        {performed += 1; } // callback?
      if (callback != null) {callback!();}
    } while (performed < repeat && result == MoveResult.ok && canMove(move));
    if (result != MoveResult.finish && result != MoveResult.killed && isStuck())
    { 
      mrMatt = grid.findMrMatt();
      result = MoveResult.stuck;
    }
    // playTileMoves(); // for now, should be done in interface to simulate movement
    takeSnapshot(startGrid, move, result, performed-1, mrMatt);
    logDebug('SNAPSHOT: end performMove {${nowString('HH:mm:ss.S')}} ($result): repeat = ${lastMove!.repeat}');
    return result;     
  }
  bool isStuck(){
    for (Move move in [Move.left,Move.up, Move.down,Move.right]) {
      if (canMove(move)) {return false;}
    }
    return true;
  }
  MoveResult _performMove(Move move, FallHandler handler) {
    _log('starting _performMove ($move) target ($move)');    
    RowCol target = _rolColFromMove(move);
    int currentRow = mrMatt.row;
    int currentCol = mrMatt.col;
    MoveResult result = MoveResult.ok;
    if (isHorizontalMove(move) &&
        grid.cell(target.row,target.col).isMovable() &&
        _checkCanMoveObject(target.row, target.col)) {
        _log('Horizontal move: target $target (${grid.cell(target.row,target.col)})');
      result = _moveObject(target.row, target.col, move, handler);
      if (result != MoveResult.ok) {
        return result;
      }
    }    
    moveMrMatt(target.row, target.col);
    if (!GridConst.isTop(currentRow) && isHorizontalMove(move)) {
      _log('dropping [${currentRow-1},$currentCol]');
      result = handler.handleAll(currentRow-1, currentCol);
      _log('--- dropping result is $result');
    }
    if (nrFood == 0) {
      _log('FINISHED!');
      result = MoveResult.finish;
    }
    _log('--- _performMove result is $result');
    return result;
  }
  bool _stuffAboveMrMattBlocksVerticalMove(Move move) {
      switch (move) {
        case Move.up: 
        case Move.down: {
          if (GridConst.isTop(mrMatt.row)) return false;
          Tile cell = grid.cell(mrMatt.row-1,mrMatt.col);
          return cell.isMovable();
        }
        default:
          return false; 
      }
  }
  int undoLast() {
    if (snapshots.isEmpty) {return 0;}
    GameSnapshot lastSnapshot = snapshots.removeLast();
    grid = lastSnapshot.previousGrid;
    nrFood = grid.nrFood();    
    mrMatt = grid.findMrMatt(); 
    return lastSnapshot.nrMoves;
  }
  void _doCallBack() {
    if (callback != null) {
        // await Future.delayed(Durations.short1);
        // logDebug('before callback');
        callback!();
        // logDebug('after callback');
        // await Future.delayed(Durations.short1);
      }
  }
  void moveTile(int rowStart,int colStart,int rowEnd,int colEnd,TileType tileTypeEnd) async {
    grid.cell(rowStart,colStart).setEmpty();
    grid.cell(rowEnd,colEnd).setTileType(tileTypeEnd);
    tileMoves.push(rowStart,colStart,rowEnd,colEnd,tileTypeEnd);
    logDebug('moveTile: ${tileMoves.last} (van ${tileMoves.length})  callback: $callback');
    _doCallBack();
    }
  // Future<MoveResult> playBack(Moves moves, Function(MoveRecord, MoveResult)? callback) async {
  //   MoveResult result = MoveResult.invalid;
  //   for (MoveRecord move in moves.moves) {
  //       result = await performMove(move.move, move.repeat);
  //       if (callback!=null) {callback(move, result);}
  //       if (result != MoveResult.ok){break;}
  //   }
  //   return result;
  // }
}

