import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum TileType {empty, mrMatt, stone, wall, bomb, box1, box2, box3, grass, food, loser}
class Tile {
  late TileType _tileType;
  TileType get tileType=>_tileType;
  set tileType(TileType? value)=>_tileType = value?? TileType.empty;
  late int _row;
  int get row =>_row;
  late int _col;
  int get col =>_col;
  Tile([TileType? tileType,int? row, int? col]){
    _tileType=tileType??TileType.empty;
    _row=row??-1;
    _col=col??-1; 
  }
  Tile.copy(Tile tile) {
    _tileType=tile.tileType;
    _row=tile.row;
    _col=tile.col;
  }
  static Tile getEmptyTile() => Tile();
  Tile.parse(String char) {
    TileType tt = TileType.empty;
    switch(char) {
      case '-': tt = TileType.grass;
      case '!': tt = TileType.bomb;
      case '*': tt = TileType.stone;
      case '=': tt = TileType.box3;
      case '+': tt = TileType.food;
      case '#': tt = TileType.wall;
      case 'H': tt = TileType.mrMatt;
      case ' ': tt = TileType.empty;
      default: throw(ArgumentError('unknown character [$char] in line, cannot be parsed.'));
    }
    tileType = tt;
  }
  @override
  String toString() { 
    return '<${tileType.name}>';
  }
  String dumpStr() {
    switch (tileType){
      case TileType.empty: return '  ';
      case TileType.mrMatt: return'M ';
      case TileType.stone: return  'R ';
      case TileType.wall: return  'W ';
      case TileType.bomb: return  'B ';
      case TileType.box1: return  'b1';
      case TileType.box2: return  'b2';
      case TileType.box3: return  'b3';
      case TileType.grass: return 'G ';
      case TileType.food: return  'F ';
      case TileType.loser: return 'L ';
      default: return '?!';      
    }
  }  
  bool isEmpty()=>tileType == TileType.empty;
  bool isMrMatt()=>tileType == TileType.mrMatt;  
  bool isLoser()=>tileType == TileType.loser;  
  bool isStone()=>tileType == TileType.stone;
  bool isWall()=>tileType == TileType.wall; 
  bool isBomb()=>tileType == TileType.bomb;
  bool isBox()=>tileType == TileType.box1 ||
                tileType == TileType.box2 ||
                tileType == TileType.box3;
  bool isGrass()=>tileType == TileType.grass;  
  bool isFood()=>tileType == TileType.food;  
  bool isConsumable()=>isGrass() || isFood();
  bool isMovable()=>isStone() || isBomb() || isBox();
  bool isBombFree()=>isBox() || isConsumable() || isEmpty() || isMrMatt();
  void setEmpty()=>tileType=TileType.empty;
  void setMrMatt()=>tileType=TileType.mrMatt;
  void setStone()=>tileType=TileType.stone;
  void setWall()=>tileType=TileType.wall;
  void setBomb()=>tileType=TileType.bomb;
  void setBox(int value) {
    if (value == 1) {tileType=TileType.box1;}
    else if (value == 2) {tileType=TileType.box2;}
    else if (value == 3) {tileType=TileType.box3;}
    else {throw(ArgumentError('Invalid argument for setBox: $value'));}
  }
  void setGrass()=>tileType=TileType.grass;
  void setFood()=>tileType=TileType.food;
  void setLoser()=>tileType=TileType.loser;
  Tile boxConsume(Tile tile) {
    assert (isBox());
    TileType newType;
    if (tileType == TileType.box3) {newType=TileType.box2;}
    else if (tileType == TileType.box2) {newType=TileType.box1;}
    else if (tileType == TileType.box1) {newType=TileType.empty;}
    else {throw(ArgumentError('Unexpected tiletype "$tile"'));}
    return Tile(newType,tile.row,tile.col);  
  }
}

class RowCol {
  late int row;
  late int col;
  RowCol(this.row, this.col);
  RowCol.copy(RowCol value) {
    row = value.row;
    col = value.col;
  }
  @override
  String toString() {
    return '[$row,$col]';
  }
}

class GridConst{
  static const mattHeight = 18;
  static const mattWidth  = 31;
  static bool isGridRow(int row)=>row >=0 && row < mattHeight;
  static bool isGridCol(int col)=>col >=0 && col < mattWidth;
  static bool isGridRowCol(int row, int col)=>isGridRow(row) && isGridCol(col);
  static bool isTop(int row)=> row==0;
  static bool isBottom(int row)=> row==mattHeight-1;
  static bool isLeft(int col)=> col==0;
  static bool isRight(int col)=> col==mattWidth-1;
  
  static Iterable<int> rowRange([int start = 0,int end=mattHeight]) sync* {
    for (int row = start; row < end; row++) {
      yield row;
    }
  }
  static Iterable<int> colRange([int start = 0,int end=mattWidth]) sync* {
    for (int col = start; col < end; col++) {
      yield col;
    }
  }
}
class GridColumn {
  List<Tile> _rows = [];
  List<Tile> get rows=>_rows;
  int _col = 0;
  int get col =>_col;
  GridColumn(int col) {
    _col=col;
    for (int row in GridConst.rowRange()) {
      _rows.add(Tile(TileType.empty,row,col));
    }
  }
  GridColumn.copy(GridColumn column) {
    if (_rows.isNotEmpty){
      _rows = [];
    }
    for (int row in GridConst.rowRange()) {
      _rows.add(Tile.copy(column.rows[row]));
    }
  }
  void _checkRow(int row){ 
    if (!GridConst.isGridRow(row)) {
      throw(ArgumentError('Invalid row: $row'));
    }
  }
  Tile cell(int row) {
    _checkRow(row);
    return _rows[row];
  }
  Tile setCell(int row, Tile tile){
    _checkRow(row);
    rows[row] = tile;
    tile._row=row;
    tile._col=col;
    return rows[row];
  }
}
class Grid {
  List<GridColumn> _columns = [];
  List<GridColumn> get columns=>_columns;
  Grid() {
    for (int col in GridConst.colRange()){
      _columns.add(GridColumn(col));
    }
  }
  Grid.copy(Grid board) {
    if (_columns.isNotEmpty) {
      _columns = [];
    }
    for (int col in GridConst.colRange()){
      _columns.add(GridColumn.copy(board.columns[col]));
    }
  }
  void _checkCol(int col){ 
    if (!GridConst.isGridCol(col)) {
      throw(ArgumentError('Invalid column: $col'));
    }
  }
  Tile cell(int row, int col) {
    _checkCol(col);
    return columns[col].cell(row);
  }
  Tile setCell(int row, int col, Tile tile) {
    GridColumn column = columns[col];
    column.setCell(row, tile);
    return cell(row,col);
  }
  GridColumn column(int col) {
    _checkCol(col);
    return columns[col];    
  }
  List<Tile> row(int row) {
    List<Tile> result = [];
    for (int col in GridConst.colRange()){
      result.add(cell(row,col));
    }
    return result;
  }
  int nrFood() {
    int result = 0;
    for (int row in GridConst.rowRange()){
      for (int col in GridConst.colRange()){
        Tile tile = cell(row,col);
        if (tile.isFood()) {
          result ++;
        }
      }
    }
    return result;
  }
  RowCol findMrMatt(){
    for (int row in GridConst.rowRange()){
      for (int col in GridConst.colRange()){
        Tile tile = cell(row,col);
        if (tile.isMrMatt()) {
          return RowCol(row,col);
        }
      }
    }
    throw(StateError('MrMatt not found...'));
  }
  void dump() {
    if (kDebugMode) {
      stdout.write('  ');
      for (int col in GridConst.colRange()){
        stdout.write(col.toString().padLeft(3,' '));
      }
      stdout.write('\n');
      for (int row in GridConst.rowRange()){
        stdout.write('${row.toString().padRight(2,' ')}: ');
        for (int col in GridConst.colRange()){
          stdout.write(cell(row,col).dumpStr());
          if (!GridConst.isRight(col)) {
            stdout.write(' ');
          }
        }
        stdout.write('\n');
      }
    }
  }
}

int random(int start, int end) {
  final random = Random();
  return start + random.nextInt(end - start);  
}
TileType getRandomTile(){
  const Map<int,TileType> mapToTile = 
  {0:TileType.empty, 1:TileType.stone, 2:TileType.wall, 3:TileType.bomb, 4:TileType.box1, 5:TileType.box2, 6:TileType.box3, 7:TileType.grass, 8:TileType.food};
  return mapToTile[random(0,9)]??TileType.empty;
}

Grid createRandomGrid() {
  Grid result = Grid();
  int mrMattRow = random(0,GridConst.mattHeight);
  int mrMattCol = random(0,GridConst.mattWidth);
  for (int row in GridConst.rowRange()) {
    for (int col in GridConst.colRange()) {
      if (row == mrMattRow && col == mrMattCol) {
        result.cell(row,col).setMrMatt();
      }
      else {
        result.cell(row,col).tileType = getRandomTile();
      }
    }
  }
  return result;
}