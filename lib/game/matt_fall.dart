import "matt_grid.dart";
import "matt_game.dart";
import "../log.dart";

class FallHandler {
  late Grid _grid;
  Grid get grid => _grid;
  FallHandler(Grid grid){
    _grid = grid;
  }
  MoveResult handleAll(int row, int col) {
    MoveResult result = MoveResult.ok;
    // bool first = true;
    logDebug('Dropping ALL [$row,$col] ${grid.cell(row,col)}');
    while (result != MoveResult.killed && result != MoveResult.finish && 
          GridConst.isGridRow(row) && grid.cell(row,col).isMovable()) { 
      result = handle(row,col);
      logDebug('\tdropped one [$row,$col] ${grid.cell(row,col)}: $result.');
      // if (result == MoveResult.ok && (!first && GridConst.isTop(row))) {break;}
      // first = false;
      // if (GridConst.isTop(row)) {break;} else {row -=1;}
      row -=1;
    } 
    logDebug('...End Dropping ALL  [$row,$col]: $result.');
    return result;
  }
  MoveResult _killedMrMatt(Tile tile) {
    assert(tile.isMrMatt());
      logDebug('Oh no...');
      tile.setLoser();
      return MoveResult.killed;         
  }
  MoveResult handle(int row, int col, {bool initial=true}) {
    // how movable object at [row,col] drops
    assert (GridConst.isGridRow(row) && GridConst.isGridCol(col));
    Tile tile = Tile.copy(grid.cell(row,col));
    if (!tile.isMovable()){
      logDebug('tile at $row,$col ($tile) is not movable');
      return MoveResult.ok;
    }
    logDebug('START drop [$row,$col] ($tile)');
    if (GridConst.isBottom(row)){
      logDebug('--- END drop (at bottom)');
      if (!initial) {
        _testBomb(row, col, tile, null);
      }
      return MoveResult.ok;
    }
    Tile below = grid.cell(row+1,col);
    logDebug('Below [${row+1},$col] $below');        
    if (!initial && below.isMrMatt()) {
      return _killedMrMatt(below);
    }
    try {
      MoveResult? result = _dropOneRow(row, col, tile, below, initial);
      if (result == null){
        logDebug('--- END drop (restoring the tile)');
        grid.setCell(row,col, tile); 
        return MoveResult.invalid;
      }
      return result;
    }
    on Exception catch(e) {
      logDebug('oops... $e');
      return MoveResult.invalid;
    }
  }

  MoveResult? _dropOneRow(int row, int col, Tile tile, Tile below, [bool initial=true]) {   
    if (_emptyBelow(row,col,tile,below)) {
      grid.cell(row,col).setEmpty();
      grid.setCell(row+1,col,tile);
      MoveResult result = handle(row+1,col, initial:false);
      if (result == MoveResult.invalid) {
        grid.cell(row+1,col).setEmpty();
        grid.setCell(row,col,tile);
        logDebug('...restored');
      }
      logDebug('end _emptyBelow $result');
      return result;
    }
    else if (_wallBelow(row, col, tile, below) || 
             _consumableBelow(row, col, tile, below) ||
             _boxBelow(row, col, tile, below) ||
             _bombBelow(row, col, tile, below) ||
             _rockBelow(row, col, tile, below)) {
      if (!initial && _testBomb(row,col,tile, below)) {
        grid.cell(row,col).setEmpty();
        below.setEmpty();
      }
      if (below.isStone())
        {return _handleRockBelow(row,col,tile,below);}      
      else
        {return MoveResult.ok;}
    }
    else       
      {throw('Unexpected situation for [$row,$col]. Sorry. tile: $tile below $below.');}
  }
  
  bool _emptyBelow(int row, int col, Tile tile, Tile below)=>_testBelow(row, col, tile, below, below.isEmpty, 'empty');
  bool _wallBelow(int row, int col, Tile tile, Tile below) =>_testBelow(row, col, tile, below, below.isWall,'wall');
  bool _consumableBelow(int row, int col, Tile tile, Tile below) => _testBelow(row,col,tile,below,below.isConsumable,'consumable');
  bool _bombBelow(int row, int col, Tile tile, Tile below)=> _testBelow(row, col, tile, below, below.isBomb, 'bomb');
  bool _rockBelow(int row, int col, Tile tile, Tile below)=> _testBelow(row, col, tile, below, below.isStone, 'rock');
  bool _boxBelow(int row, int col, Tile tile, Tile below) {
    if (_testBelow(row, col, tile, below, below.isBox, 'box')) {
      grid.cell(row,col).setEmpty();
      grid.setCell(row+1,col, below.boxConsume(tile));
      logDebug('Handled box (tile: $tile  box after: ${grid.cell(row+1,col)})');
      return true;
    }
    return false;
  }
  bool _testBelow(int row, int col, Tile tile, Tile below, bool Function() test, String msg) {
    if (test()) {
      logDebug('$msg tested true: ($tile)');
      return true;
    }
    return false;
  }

  bool _testBomb(int row, int col, Tile tile, Tile? below) {
      if (!tile.isBomb())
        {return false;}
      if (below != null && below.isBombFree()) {
        logDebug('bomb will not explode on $below.');
        return false;
      }
      logDebug('bomb EXPLODES! on ${below ?? "bottom"}');
      if (below != null)
        {grid.cell(row+1, col).setEmpty();}
      return true;      
  }
  MoveResult? _handleRockBelow(row,col,tile,Tile below) {
    assert (below.isStone());    
    // ignoring the case where both left and right are possible for now
    logDebug('handling rock below for [$row,$col] $tile');
    logDebug('=== try left ===');
    MoveResult? result = _handleSide(row, col, -1, tile, GridConst.isLeft);
    if (result!=null) {
      logDebug('=== end handling rock below for [$row,$col]: $result');
      return result;
    }
    logDebug('=== try right ===');
    result = _handleSide(row, col, 1, tile, GridConst.isRight);
    logDebug('=== end handling rock below for [$row,$col]: $result');
    return result ?? MoveResult.ok;
  }
  MoveResult? _handleSide(int row, int col, int delta, Tile tile, bool Function(int) borderTest){
    Tile? side = borderTest(col)?null:grid.cell(row,col+delta);
    Tile? sideBelow = borderTest(col)?null:grid.cell(row+1,col+delta);    
    logDebug('...handling side for [$row,$col] $tile | side [$row,${col+delta} $side | sidebelow [${row+1},${col+delta}] $sideBelow');
    if (side != null && side.isEmpty() && sideBelow != null) {
      if (sideBelow.isEmpty()){      
        grid.cell(row,col).setEmpty();
        grid.setCell(row,col+delta,tile);
        logDebug('...continue handling side');
        return handle(row,col+delta,initial:false);
      }
      else if (sideBelow.isMrMatt()) {
        grid.cell(row,col).setEmpty();
        grid.setCell(row,col+delta,tile);
        return _killedMrMatt(sideBelow);
      }
    }
    logDebug('...end handling side (null)');
    return null;
  }
}