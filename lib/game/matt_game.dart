import "dart:collection";
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

  Queue<GameSnapshot> snapshots = Queue();

  MattGame(Grid grid, {required this.level, required this.title}){
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
    logDebug('Moves: $moves');
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
      logDebug('---at border');    
      return false;
    }
    Tile nextCell = grid.cell(row, nextCol);
    bool isEmpty = nextCell.isEmpty();
    logDebug('---next cell $nextCell  (empty: $isEmpty)');    
    return isEmpty;
  }
  bool canMove(Move move) {
    if (_stuffAboveMrMattBlocksVerticalMove(move)) {
      return false;
    }
    RowCol targetLoc = _rolColFromMove(move);
    logDebug('Start canMove  $move to ($targetLoc)');    
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
      logDebug('WALL');
      return false;
    }
    else if (target.isConsumable() || target.isEmpty()) 
    {
      logDebug('---consumable or empty [canMove:TRUE]');          
      return true;
    }
    else if (target.isMovable()) {
        // can only move one item in a row, not up or down
      if (isHorizontalMove(move)) {
        bool result = targetLoc.row == mrMatt.row && _checkCanMoveObject(targetLoc.row, targetLoc.col);
        logDebug('---movable [canMove: $result]');
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
    grid.cell(mrMatt.row, mrMatt.col).setEmpty();
    if (grid.cell(row,col).isFood()) {
      nrFood -= 1;
    }
    grid.cell(row,col).tileType=TileType.mrMatt;
    mrMatt = RowCol(row,col);
    logDebug('Moved mrMatt to $mrMatt');
  }
  MoveResult _moveObject(int row, int col, Move move, FallHandler handler) {
    assert (isHorizontalMove(move));
    int targetCol = move == Move.left ? col-1 : col+1;
    assert (grid.cell(row,targetCol).isEmpty());
    logDebug('moving object at [$row,$col] to $targetCol');
    grid.cell(row,targetCol).tileType = grid.cell(row,col).tileType;
    MoveResult dropResult = handler.handle(row, targetCol);    
    logDebug('dropResult: $dropResult');
    return dropResult;
  }
    
  MoveResult performMove(Move move, [int repeat = 0]) {
    logDebug('Start perform move ($move) target ($move) repeat:$repeat');    
    if (!canMove(move)) {
      logDebug('--- invalid move');    
      return MoveResult.invalid;
    }
    FallHandler handler = FallHandler(grid);
    MoveResult result;
    RowCol mrMatt = RowCol(this.mrMatt.row,this.mrMatt.col);  
    Grid current = Grid.copy(grid);
    int performed = 0;
    do {
      result = _performMove(move, handler);
      if (result != MoveResult.invalid)
        {performed += 1;}
    } while (performed < repeat && result == MoveResult.ok && canMove(move));
    if (result != MoveResult.finish && result != MoveResult.killed && isStuck())
    { 
      mrMatt = grid.findMrMatt();
      grid.cell(mrMatt.row,mrMatt.col).setLoser();
      result = MoveResult.stuck;
    }
    takeSnapshot(current, move, result, performed-1, mrMatt);
    logDebug('SNAPSHOT: performMove ($result): repeat = ${lastMove!.repeat}');
    return result;     
  }
  bool isStuck(){
    for (Move move in [Move.left,Move.up, Move.down,Move.right]) {
      if (canMove(move)) {return false;}
    }
    return true;
  }
  MoveResult _performMove(Move move, FallHandler handler) {
    logDebug('starting _performMove ($move) target ($move)');    
    RowCol target = _rolColFromMove(move);
    int currentRow = mrMatt.row;
    int currentCol = mrMatt.col;
    MoveResult result = MoveResult.ok;
    if (isHorizontalMove(move) &&
        grid.cell(target.row,target.col).isMovable() &&
        _checkCanMoveObject(target.row, target.col)){
        logDebug('Horizontal move: target $target (${grid.cell(target.row,target.col)})');
      result = _moveObject(target.row, target.col, move, handler);
      if (result != MoveResult.ok) {return result;}
    }    
    moveMrMatt(target.row, target.col);
    if (!GridConst.isTop(currentRow) && isHorizontalMove(move)) {
      logDebug('dropping [${currentRow-1},$currentCol]');
      result = handler.handleAll(currentRow-1, currentCol);
      logDebug('--- dropping result is $result');
    }
    if (nrFood == 0) {
      logDebug('FINISHED!');
      result = MoveResult.finish;
    }
    logDebug('--- _performMove result is $result');
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
  MoveResult playBack(Moves moves, Function(MoveRecord, MoveResult)? callback) {
    MoveResult result = MoveResult.invalid;
    for (MoveRecord move in moves.moves) {
        result = performMove(move.move, move.repeat);
        if (callback!=null) {callback(move, result);}
        if (result != MoveResult.ok){break;}
    }
    return result;
  }
}

