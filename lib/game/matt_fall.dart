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
  final bool _detailedLog = false;

  void _log(String s){ 
    if (_detailedLog) logDebug(s);
  }
  FallHandler(Grid grid, TileMoves tileMoves, [Function()? callback]){
    _grid = grid;
    _tileMoves = tileMoves;
    _callback = callback;
  }
  MoveResult handleAll(int row, int col) {
    MoveResult result = MoveResult.ok;
    // bool first = true;    
    _log('Dropping ALL [$row,$col] ${grid.cell(row,col)}');
    while (//result != MoveResult.killed && result != MoveResult.finish && 
          GridConst.isGridRow(row) && grid.cell(row,col).isMovable()) { 
      MoveResult temResult = handle(row,col);
      _log('\tdropped one [$row,$col] ${grid.cell(row,col)}: $temResult.');
      if (result == MoveResult.ok && temResult != MoveResult.ok) {
        result = temResult;
      }
      // if (result == MoveResult.ok && (!first && GridConst.isTop(row))) {break;}
      // first = false;
      // if (GridConst.isTop(row)) {break;} else {row -=1;}
      row -=1;
    } 
    _log('...End Dropping ALL  [$row,$col]: $result.');
    return result;
  }
  
  void _doCallBack(){
    if (_callback != null) {
      _callback!();
      // await Future.delayed(Durations.short1);
    }
  }
  void moveTile(int rowStart,int colStart, int rowEnd, int colEnd, TileType tileTypeEnd) async {
    grid.cell(rowStart,colStart).setEmpty();
    grid.setCell(rowEnd, colEnd, Tile(tileTypeEnd));
    tileMoves.push(rowStart, colStart, rowEnd, colEnd, tileTypeEnd);
    logDebug('moveTile(fallhandler): ${tileMoves.last}');
    _doCallBack();
  }

  MoveResult _killedMrMatt(Tile tile) {
    assert(tile.isMrMatt());
      _log('Oh no...');
      // mutate(tile.row,tile.col, TileType.loser);
      return MoveResult.killed;         
  }
  MoveResult handle(int row, int col, {bool initial=true}) {
    // how movable object at [row,col] drops
    assert (GridConst.isGridRow(row) && GridConst.isGridCol(col));
    Tile tile = Tile.copy(grid.cell(row,col));
    if (!tile.isMovable()){
      _log('tile at $row,$col ($tile) is not movable');
      return MoveResult.ok;
    }
    _doCallBack();
    _log('START drop [$row,$col] ($tile)');
    if (GridConst.isBottom(row)){
      _log('--- END drop (at bottom)');
      if (!initial) {
        _testBomb(row, col, tile, null);
      }
      return MoveResult.ok;
    }
    _doCallBack();
    Tile below = grid.cell(row+1,col);
    _log('Below [${row+1},$col] $below');        
    if (!initial && below.isMrMatt()) {
      return _killedMrMatt(below);
    }
    try {
      MoveResult? result = _dropOneRow(row, col, tile, below, initial);
      _doCallBack();
      if (result == null){
        _log('--- END drop (restoring the tile)');
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
      moveTile(row,col,row+1,col,tile.tileType);
      MoveResult result = handle(row+1,col, initial:false);
      if (result == MoveResult.invalid) {        
        moveTile(row+1,col,row,col,tile.tileType);
        _log('...restored');
      }
      _log('end _emptyBelow $result');
      return result;
    }
    else if (_wallBelow(row, col, tile, below) || 
             _consumableBelow(row, col, tile, below) ||
             _boxBelow(row, col, tile, below) ||
             _bombBelow(row, col, tile, below) ||
             _rockBelow(row, col, tile, below)) {
      if (!initial && _testBomb(row,col,tile, below)) {
        moveTile(row,col,below.row,below.col,TileType.empty);
      }
      if (below.isStone())
        {return _handleRockBelow(row,col,tile,below);}      
      else
        {return MoveResult.ok;}
    }
    else       
      {throw(MrMattException('Unexpected situation for [$row,$col]. Sorry. tile: $tile below $below.'));}
  }
  
  bool _emptyBelow(int row, int col, Tile tile, Tile below)=>_testBelow(row, col, tile, below, below.isEmpty, 'empty');
  bool _wallBelow(int row, int col, Tile tile, Tile below) =>_testBelow(row, col, tile, below, below.isWall,'wall');
  bool _consumableBelow(int row, int col, Tile tile, Tile below) => _testBelow(row,col,tile,below,below.isConsumable,'consumable');
  bool _bombBelow(int row, int col, Tile tile, Tile below)=> _testBelow(row, col, tile, below, below.isBomb, 'bomb');
  bool _rockBelow(int row, int col, Tile tile, Tile below)=> _testBelow(row, col, tile, below, below.isStone, 'rock');
  bool _boxBelow(int row, int col, Tile tile, Tile below) {
    if (_testBelow(row, col, tile, below, below.isBox, 'box')) {
      moveTile(row,col,row+1,col,below.boxConsume(tile));
      return true;
    }
    return false;
  }
  bool _testBelow(int row, int col, Tile tile, Tile below, bool Function() test, String msg) {
    if (test()) {
      _log('$msg tested true: ($tile)');
      return true;
    }
    return false;
  }

  bool _testBomb(int row, int col, Tile tile, Tile? below) {
      if (!tile.isBomb())
        {return false;}
      if (below != null && below.isBombFree()) {
        _log('bomb will not explode on $below.');
        return false;
      }
      _log('bomb EXPLODES! on ${below ?? "bottom"}');
      if (below != null) {
        moveTile(row,col,row+1,col,TileType.empty);
      }
      return true;      
  }
  MoveResult? _handleRockBelow(row,col,tile,Tile below) {
    assert (below.isStone());    
    // ignoring the case where both left and right are possible for now
    _log('handling rock below for [$row,$col] $tile');
    _log('=== try left ===');
    MoveResult? result = _handleSide(row, col, -1, tile, GridConst.isLeft);
    if (result!=null) {
      _log('=== end handling rock below for [$row,$col]: $result');
      return result;
    }
    _log('=== try right ===');
    result = _handleSide(row, col, 1, tile, GridConst.isRight);
    _log('=== end handling rock below for [$row,$col]: $result');
    return result ?? MoveResult.ok;
  }
  MoveResult? _handleSide(int row, int col, int delta, Tile tile, bool Function(int) borderTest){
    Tile? side = borderTest(col)?null:grid.cell(row,col+delta);
    Tile? sideBelow = borderTest(col)?null:grid.cell(row+1,col+delta);    
    _log('...handling side for [$row,$col] $tile | side [$row,${col+delta} $side | sidebelow [${row+1},${col+delta}] $sideBelow');
    if (side != null && side.isEmpty() && sideBelow != null) {
      if (sideBelow.isEmpty()){      
        moveTile(row,col,row,col+delta,tile.tileType);
        _log('...continue handling side');
        return handle(row,col+delta,initial:false);
      }
      else if (sideBelow.isMrMatt()) {
        moveTile(row,col,row,col+delta,tile.tileType);
        return _killedMrMatt(sideBelow);
      }
    }
    _log('...end handling side (null)');
    return null;
  }
}