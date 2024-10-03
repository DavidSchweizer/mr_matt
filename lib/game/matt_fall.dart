// ignore: unused_import
import "dart:collection";

// ignore: unused_import
import "package:flutter/material.dart";

import "../utils/log.dart";
import "matt_grid.dart";
import "matt_game.dart";

class FallHandler {
  late Grid _grid;
  Grid get grid => _grid;
  late TileMoves _tileMoves;
  TileMoves get tileMoves =>_tileMoves;
  late Function()? _callback;
  final bool _detailedLog = false;

  void _log(String s){ 
    if (_detailedLog) logDebug(s);
  }
  FallHandler(Grid grid, TileMoves tileMoves, [Function()? callback]){
    _grid = grid;
    _tileMoves = tileMoves;
    _callback = callback;
  }
  Queue<int> _findDropTiles(int row, int col) {
    Queue<int> result = Queue<int>();
    while (GC.isGridRow(row) && grid.cell(row,col).isMovable()) {
      result.addLast(row);
      row--;
    }
    String ss = '-- drop tiles ($row,$col):';
    if (result.isEmpty) {ss += 'none';}
    else {
      for (int row2 in result) {
        ss += ' $row2';
      }
    }
    logDebug(ss);
    return result;
  }
  
  MoveResult handleAll(int row, int col, Move move) {
    assert (isHorizontalMove(move));
    MoveResult result = MoveResult.ok;
    _log('Dropping ALL ${grid.cell(row,col).dbgString()}');
    Queue<int> tilesToDrop = _findDropTiles(row,col);
    while (tilesToDrop.isNotEmpty /*&& result == MoveResult.ok*/) {
      int stoneRow = tilesToDrop.removeFirst();
      MoveResult temResult = handleOne(stoneRow, col, move);
      _log('\thandled ($stoneRow,$col) $temResult.');
      if (result == MoveResult.ok && temResult != MoveResult.ok) {
        result = temResult;
      }
    }
    return result;
  }

  void _doCallBack(){
    if (_callback != null) {
      _callback!();
      // await Future.delayed(Durations.short1);
    }
  }
  void moveTile(int rowStart, int colStart, int rowEnd, int colEnd, [TileType? tileTypeEnd]) async {
    TileType tileType = tileTypeEnd??grid.cell(rowStart,colStart).tileType;
    grid.cell(rowStart,colStart).setEmpty();
    grid.setCell(rowEnd, colEnd, Tile(tileType));
    tileMoves.push(rowStart, colStart, rowEnd, colEnd, tileType);
    logDebug('moveTile(fallhandler): ${tileMoves.last}');
    _doCallBack();
  }

  int _findEndRow(int row, int col) {
    int result = row+1;
    while (GC.isGridRow(result) && grid.cell(result,col).isEmpty()) { 
      result++;
    }
    return /*GC.isGridRow(result) ? result : */ result-1;
  }

  MoveResult _dropToBottom(Tile tile) {
    _log('--- END drop (at bottom)');
    if (_testBomb2(tile, null)) {
      moveTile(tile.row,tile.col,GC.bottomRow, tile.col, TileType.empty);
    }
    else {
      moveTile(tile.row,tile.col,GC.bottomRow, tile.col);
    }
    return MoveResult.ok;
  }

  bool _testBomb2(Tile tile, Tile? below) {
      if (!tile.isBomb())
        {return false;}
      if (below != null && below.isBombFree()) {
        //note: if below is a box, the box will swallow the bomb
        _log('bomb will not explode on ${below.dbgString()}.');
        return false;
      }
      _log('bomb EXPLODES! on ${below?.dbgString() ?? "bottom"}');
      return true;      
  }

  MoveResult handleOne(int row, int col, Move move) {
    assert (GC.isGridRow(row) && GC.isGridCol(col));
    Tile tile = Tile.copy(grid.cell(row,col));
    assert(tile.isMovable());
    int rowEnd = _findEndRow(row,col);
    _log('START drop [$row,$col]->[$rowEnd,$col] ($tile)');
    if (rowEnd == row) {return MoveResult.ok;} // moveObject can mean no falling
    else if (GC.isBottom(rowEnd)){ return _dropToBottom(tile);}
    Tile below = grid.cell(rowEnd+1,col);
    _log('Below ${below.dbgString()}');
    return _handleLanding(tile, below, move);
  }

  MoveResult _handleMrMatt(Tile tile, Tile below, Move move) {
    assert(below.isMrMatt()); 
    _log('Oh no...');
    moveTile(tile.row,tile.col, below.row-1,below.col);
    return MoveResult.killed;
  }
  MoveResult _handleBox(Tile tile, Tile below, Move move) {
      _log('...boxing ${tile.dbgString} ${below.dbgString()}');
      moveTile(tile.row,tile.col,below.row,below.col,Tile.boxConsume(below));
      return MoveResult.ok;
  }
  MoveResult _handleSimple(Tile tile, Tile below, Move move) {
    assert(!tile.isBomb() || below.isBombFree());
    _log('...just landing (${below.dbgString()})');
    moveTile(tile.row,tile.col,below.row-1,below.col);
    return MoveResult.ok;
  }
  MoveResult _handleLanding(Tile tile, Tile below, Move move) {
    Map<TileType,MoveResult Function(Tile,Tile, Move)> handlers = {
      TileType.mrMatt: _handleMrMatt,
      TileType.box1: _handleBox,
      TileType.box2: _handleBox,
      TileType.box3: _handleBox,
      TileType.food: _handleSimple,
      TileType.grass: _handleSimple,
      TileType.wall: _handleSimple,
      TileType.bomb: _handleSimple,
      TileType.stone: _handleStoneBelow,
    };
    if (_testBomb2(tile, below)){
      _log('...exploding bomb $tile $below');
      moveTile(tile.row,tile.col,below.row,below.col,TileType.empty);
      return MoveResult.ok;
    } 
    else {
      if (!handlers.keys.contains(below.tileType)){
        throw(MrMattException('Unexpected landing site: $below, cannot handle.'));
      }
      return handlers[below.tileType]!(tile,below, move);
    }
  }

  // MoveResult? _sideHandler(Tile tile, Move move){
  //   Map<Move,Map<String,dynamic>> sides = 
  //       {Move.left: {'delta': -1, 'func': GC.isLeft}, 
  //        Move.right: {'delta': 1, 'func': GC.isRight},};
  //   Map<String,dynamic> moveDict = sides[move]!;
  //   return _handleSide(moveDict['delta'], tile, moveDict[ 'func']);
  // }
  MoveResult _handleStoneBelow(Tile tile,Tile below, Move move) {
    // assumption: stone will drop to same side as mrMatt's last move if possible
    assert (below.isStone());    
    _log('handling stone {${below.dbgString()}} below ${tile.dbgString()}');
    moveTile(tile.row,tile.col, below.row-1, below.col); 
    tile = Tile.copy(grid.cell(below.row-1,below.col));
    MoveResult? result = _handleSide(tile, move);
    if (result!=null) {
      _log("=== end handling stone below >$move<: $result");
      return result;
    }
    else {
      result = _handleSide(tile, move==Move.left?Move.right:Move.left);
    }
    _log('=== end handling rock below >right<: $result');
    return result ?? MoveResult.ok; 
  }

  MoveResult? _handleSide(Tile tile, Move move){
    assert (move == Move.left || move == Move.right);
    int delta = move == Move.left ? -1 : 1;
    bool Function(int) borderTest = move == Move.left ? GC.isLeft : GC.isRight;
    
    Tile? side = borderTest(tile.col)?null:grid.cell(tile.row,tile.col+delta);
    Tile? sideBelow = borderTest(tile.col)?null:grid.cell(tile.row+1,tile.col+delta);    
    _log('...handling side for ${tile.dbgString()} | side [${tile.row},${tile.col+delta} $side | sidebelow [${tile.row+1},${tile.col+delta}] $sideBelow');
    if (side != null && !side.isEmpty() || sideBelow == null) {
      _log('no: ${sideBelow==null || side==null ?"at the border":"something blocking"}...');
      return null;
    } 
    if (!sideBelow.isEmpty()) {
      if (sideBelow.isMrMatt()) {
        return _handleMrMatt(tile,sideBelow, move);
      }
      else if (sideBelow.isBox()){
        return _handleBox(tile, sideBelow, move);
      }
      else {
        _log('--- end of drop, already something on this side ---'); 
        return null;      
      }
    }
    assert (sideBelow.isEmpty());
    _log('--- can drop further to this side...');
    moveTile(tile.row,tile.col, tile.row,tile.col+delta);
    MoveResult result = handleOne(tile.row,tile.col+delta, move);
   _log('handled side kick. $result');
    return result;
  }
}
