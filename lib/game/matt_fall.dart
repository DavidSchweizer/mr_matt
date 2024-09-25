// ignore: unused_import
import "dart:collection";

// ignore: unused_import
import "package:flutter/material.dart";

import "matt_grid.dart";
import "matt_game.dart";
import "../log.dart";

class FallHandler {
  late Grid _grid;
  Grid get grid => _grid;
  late TileMoves _tileMoves;
  TileMoves get tileMoves =>_tileMoves;
  late Function()? _callback;
  final bool _detailedLog = true;

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
    while (GridConst.isGridRow(row) && grid.cell(row,col).isMovable()) {
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
  
  MoveResult handleAll(int row, int col) {
    MoveResult result = MoveResult.ok;
    _log('Dropping ALL ${grid.cell(row,col).dbgString()}');
    Queue<int> tilesToDrop = _findDropTiles(row,col);
    while (tilesToDrop.isNotEmpty && result == MoveResult.ok) {
      int stoneRow = tilesToDrop.removeFirst();
      MoveResult temResult = handleOne(stoneRow, col);
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
    while (GridConst.isGridRow(result) && grid.cell(result,col).isEmpty()) { 
      result++;
    }
    return /*GridConst.isGridRow(result) ? result : */ result-1;
  }

  MoveResult _dropToBottom(Tile tile) {
    _log('--- END drop (at bottom)');
    if (_testBomb2(tile, null)) {
      moveTile(tile.row,tile.col,GridConst.bottomRow, tile.col, TileType.empty);
    }
    else {
      moveTile(tile.row,tile.col,GridConst.bottomRow, tile.col);
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

  MoveResult handleOne(int row, int col) {
    assert (GridConst.isGridRow(row) && GridConst.isGridCol(col));
    Tile tile = Tile.copy(grid.cell(row,col));
    assert(tile.isMovable());
    int rowEnd = _findEndRow(row,col);
    _log('START drop [$row,$col]->[$rowEnd,$col] ($tile)');
    if (GridConst.isBottom(rowEnd)){ return _dropToBottom(tile);}
    Tile below = grid.cell(rowEnd+1,col);
    _log('Below ${below.dbgString()}');
    return _handleLanding(tile, below);
  }

  MoveResult _handleMrMatt(Tile tile, Tile below) {
    assert(below.isMrMatt()); 
    _log('Oh no...');
    moveTile(tile.row,tile.col, below.row-1,below.col);
    return MoveResult.killed;
  }
  MoveResult _handleBox(Tile tile, Tile below) {
      _log('...boxing ${tile.dbgString} ${below.dbgString()}');
      moveTile(tile.row,tile.col,below.row,below.col,Tile.boxConsume(below));
      return MoveResult.ok;
  }
  MoveResult _handleSimple(Tile tile, Tile below) {
    assert(!tile.isBomb() || below.isBombFree());
    _log('...just landing (${below.dbgString()})');
    moveTile(tile.row,tile.col,below.row-1,below.col);
    return MoveResult.ok;
  }
  MoveResult _handleLanding(Tile tile, Tile below) {
    Map<TileType,MoveResult Function(Tile,Tile)> handlers = {
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
      return handlers[below.tileType]!(tile,below);
    }
  }

  MoveResult _handleStoneBelow(Tile tile,Tile below) {
    assert (below.isStone());    
    // ignoring the case where both left and right are possible for now
    _log('handling stone {${below.dbgString()}} below ${tile.dbgString()}');
    moveTile(tile.row,tile.col, below.row-1, below.col); 
    tile = Tile.copy(grid.cell(below.row-1,below.col));
    // note: depending on mrMatt's move?
    _log('=== try left ===');
    MoveResult? result = _handleSide(-1, tile, GridConst.isLeft);
    if (result!=null) {
      _log('=== end handling stone below >left<: $result');
      return result;
    }
    _log('=== try right ===');
    result = _handleSide(1, tile, GridConst.isRight);
    _log('=== end handling rock below >right<: $result');
    return result ?? MoveResult.ok; // if not left or right it can stay where it is!
  }

  MoveResult? _handleSide(int delta, Tile tile, bool Function(int) borderTest){
    Tile? side = borderTest(tile.col)?null:grid.cell(tile.row,tile.col+delta);
    Tile? sideBelow = borderTest(tile.col)?null:grid.cell(tile.row+1,tile.col+delta);    
    _log('...handling side for ${tile.dbgString()} | side [${tile.row},${tile.col+delta} $side | sidebelow [${tile.row+1},${tile.col+delta}] $sideBelow');
    if (side == null || !side.isEmpty() || sideBelow == null) {
      _log('--- not possible ---');
      return null;
    }
    _log('--- can drop further to this side...');
    assert (grid.cell(tile.row,tile.col+delta).isEmpty());
    grid.cell(tile.row,tile.col+delta).setStone();
    grid.cell(tile.row,tile.col).setEmpty();
    MoveResult result = handleOne(tile.row,tile.col+delta);
    if (result == MoveResult.ok) {
      _log('yes, handled side kick');
    } 
    else {
      _log('no, did not handle side kick. reverting');
      grid.cell(tile.row,tile.col+delta).setEmpty();
      grid.cell(tile.row,tile.col).setStone();
    }
    return result;
  }
}
