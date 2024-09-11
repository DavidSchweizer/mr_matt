import "dart:collection";
import "matt_grid.dart";
import "matt_fall.dart";
import "../log.dart";

enum MoveType  {none, left,up,right,down}
bool isHorizontalMove(MoveType move)=>move==MoveType.left || move==MoveType.right;
bool isVerticalMove(MoveType move)=>move==MoveType.up || move==MoveType.down;
enum MoveResult {invalid,ok,stuck,killed,finish,} // move is invalid, move OK, MrMatt can't move any more, MrMatt was killed, last apple eaten (Win!)

class MoveRecord {
  late Grid _previousGrid;
  Grid get previousGrid =>_previousGrid;
  late MoveType _move;
  MoveType get move =>_move;
  late int _repeat;
  int get repeat =>_repeat;
  late MoveResult _result;
  MoveResult get result =>_result;
  late RowCol? _mrMatt;
  RowCol get mrMatt =>_mrMatt??previousGrid.findMrMatt();
  MoveRecord(Grid previousGrid, MoveType move, {MoveResult? result,int? repeat, RowCol? mrMatt}) {
    _previousGrid = previousGrid;
    _move  = move;
    _result = result??MoveResult.invalid;
    _repeat = repeat??0;
    _mrMatt = mrMatt;
  }
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
  
  late RowCol mrMatt; // location of MrMatt
  
  Queue<MoveRecord> moves = Queue();

  MattGame(Grid grid){
    _startGrid = grid;
    this.grid = grid;
    nrFood = grid.nrFood();    
    mrMatt=grid.findMrMatt();        
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
  bool canMove(MoveType move) {
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
      throw(StateError('Multiple MrMatt'));
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
    throw (StateError('Unexpected target tile type $target'));
  }
  RowCol _rolColFromMove(MoveType move){ 
    switch (move) {
      case MoveType.left: return RowCol(mrMatt.row, mrMatt.col-1);
      case MoveType.right: return RowCol(mrMatt.row, mrMatt.col+1);
      case MoveType.up: return RowCol(mrMatt.row-1, mrMatt.col);
      case MoveType.down: return RowCol(mrMatt.row+1, mrMatt.col);
      case MoveType.none: return RowCol(mrMatt.row, mrMatt.col);
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
  MoveResult _moveObject(int row, int col, MoveType move, FallHandler handler) {
    assert (isHorizontalMove(move));
    int targetCol = move == MoveType.left ? col-1 : col+1;
    assert (grid.cell(row,targetCol).isEmpty());
    logDebug('moving object at [$row,$col] to $targetCol');
    grid.cell(row,targetCol).tileType = grid.cell(row,col).tileType;
    MoveResult dropResult = handler.handle(row, targetCol);    
    logDebug('dropResult: $dropResult');
    return dropResult;
  }
    
  MoveResult performMove(MoveType move, [int repeat = 0]) {
    logDebug('Start perform move ($move) target ($move) repeat:$repeat');    
    if (!canMove(move)) {
      logDebug('--- invalid move');    
      return MoveResult.invalid;
    }
    FallHandler handler = FallHandler(grid);
    MoveResult result;
    RowCol mrMatt = RowCol(this.mrMatt.row,this.mrMatt.col);  
    Grid current = Grid.copy(grid);
    do {
      result = _performMove(move, handler);
      repeat -=1;
    } while (repeat >= 0 && result == MoveResult.ok && canMove(move));
    moves.addLast(MoveRecord(current, move, result: result, repeat: repeat, mrMatt: mrMatt));  
    if (isStuck())
      { 
        mrMatt = grid.findMrMatt();
        grid.cell(mrMatt.row,mrMatt.col).setLoser();
        result = MoveResult.stuck;
      }
    logDebug('--- performMove result is $result');
    return result;     
  }
  bool isStuck(){
    for (MoveType move in [MoveType.left,MoveType.up, MoveType.down,MoveType.right]) {
      if (canMove(move)) {return false;}
    }
    return true;
  }
  MoveResult _performMove(MoveType move, FallHandler handler) {
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
    if (nrFood == 0) {
      logDebug('FINISHED!');
      result = MoveResult.finish;
    }
    else if (!GridConst.isTop(currentRow) && isHorizontalMove(move)) {
      logDebug('dropping [${currentRow-1},$currentCol]');
      result = handler.handleAll(currentRow-1, currentCol);
      logDebug('--- dropping result is $result');
    }
    logDebug('--- _performMove result is $result');
    return result;
  }

  bool _stuffAboveMrMattBlocksVerticalMove(MoveType move) {
      switch (move) {
        case MoveType.up: 
        case MoveType.down: {
          if (GridConst.isTop(mrMatt.row)) return false;
          Tile cell = grid.cell(mrMatt.row-1,mrMatt.col);
          return cell.isMovable();
        }
        default:
          return false; 
      }
  }
  void undoLast() {
    if (moves.isEmpty) {return;}
    MoveRecord lastMove = moves.removeLast();
    grid = lastMove.previousGrid;
    nrFood = grid.nrFood();    
    mrMatt = grid.findMrMatt();    
  }
}
