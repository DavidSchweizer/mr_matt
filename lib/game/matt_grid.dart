import 'dart:collection';

class MrMattException implements Exception {
  final String cause;
  MrMattException(this.cause);
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
  static bool isValid(row,col)=>GC.isGridRowCol(row, col);
}

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
      default: throw(MrMattException('unknown character [$char] in line, cannot be parsed.'));
    }
    tileType = tt;
  }
  @override
  String toString() { 
    return '<${tileType.name}>';
  }
  String dbgString(){
    return '($row,$col):<${tileType.name}>';
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
  void setTileType(TileType tileType)=>this.tileType=tileType;
  void setEmpty()=>setTileType(TileType.empty);
  void setMrMatt()=>setTileType(TileType.mrMatt);
  void setStone()=>setTileType(TileType.stone);
  void setWall()=>setTileType(TileType.wall);
  void setBomb()=>setTileType(TileType.bomb);
  void setBox(int value) {
    if (value == 1) {setTileType(TileType.box1);}
    else if (value == 2) {setTileType(TileType.box2);}
    else if (value == 3) {setTileType(TileType.box3);}
    else {throw(MrMattException('Invalid argument for setBox: $value'));}
  }
  void setGrass()=>setTileType(TileType.grass);
  void setFood()=>setTileType(TileType.food);
  void setLoser()=>setTileType(TileType.loser);
  static TileType boxConsume(Tile tile) {
    const Map<TileType,TileType> rules = {TileType.box3: TileType.box2, 
                                          TileType.box2: TileType.box1, 
                                          TileType.box1: TileType.empty};
    assert (tile.isBox());
    if (rules.keys.contains(tile.tileType)){return rules[tile.tileType]!;}
    throw(MrMattException('Unexpected tiletype for box "$tile"'));
  }
}

class GridConst{
  static const mattHeight = 18;
  static const mattWidth  = 31;
  static final aspectRatio = mattWidth.toDouble()/mattHeight.toDouble();
  static const bottomRow = mattHeight-1;
  static const topRow = 0;
  static const leftCol = 0;
  static const rightCol = mattWidth-1;
  static bool isGridRow(int row)=>row >=topRow && row<=bottomRow;
  static bool isGridCol(int col)=>col >=leftCol && col<=rightCol;
  static bool isGridRowCol(int row, int col)=>isGridRow(row) && isGridCol(col);
  static bool isTop(int row)=> row==topRow;
  static bool isBottom(int row)=> row==bottomRow;
  static bool isLeft(int col)=> col==leftCol;
  static bool isRight(int col)=> col==rightCol;
  static Iterable<int> rowRange([int start = topRow,int end=bottomRow]) sync* {
    for (int row = start; row <= end; row++) {
      yield row;
    }
  }
  static Iterable<int> colRange([int start = leftCol,int end=rightCol]) sync* {
    for (int col = start; col <= end; col++) {
      yield col;
    }
  }
}
typedef GC = GridConst;
class GridColumn {
  List<Tile> _rows = [];
  List<Tile> get rows=>_rows;
  int _col = 0;
  int get col =>_col;
  GridColumn(int col) {
    _col=col;
    for (int row in GC.rowRange()) {
      _rows.add(Tile(TileType.empty,row,col));
    }
  }
  GridColumn.copy(GridColumn column) {
    if (_rows.isNotEmpty){
      _rows = [];
    }
    _col = column.col;
    for (int row in GC.rowRange()) {
      _rows.add(Tile.copy(column.rows[row]));
    }
  }
  void _checkRow(int row){ 
    if (!GC.isGridRow(row)) {
      throw(MrMattException('Invalid row: $row'));
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
    for (int col in GC.colRange()){
      _columns.add(GridColumn(col));
    }
  }
  Grid.copy(Grid board) {
    if (_columns.isNotEmpty) {
      _columns = [];
    }
    for (int col in GC.colRange()){
      _columns.add(GridColumn.copy(board.columns[col]));
    }
  }
  void _checkCol(int col){ 
    if (!GC.isGridCol(col)) {
      throw(MrMattException('Invalid column: $col'));
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
  void setCellType(int row, int col, TileType tileType) {
    GridColumn column = columns[col];
    column.cell(row).setTileType(tileType);
  }
  GridColumn column(int col) {
    _checkCol(col);
    return columns[col];    
  }
  List<Tile> row(int row) {
    List<Tile> result = [];
    for (int col in GC.colRange()){
      result.add(cell(row,col));
    }
    return result;
  }
  int nrFood() {
    int result = 0;
    for (int row in GC.rowRange()){
      for (int col in GC.colRange()){
        Tile tile = cell(row,col);
        if (tile.isFood()) {
          result ++;
        }
      }
    }
    return result;
  }
  RowCol findMrMatt(){
    for (int row in GC.rowRange()){
      for (int col in GC.colRange()){
        Tile tile = cell(row,col);
        if (tile.isMrMatt()) {
          return RowCol(row,col);
        }
      }
    }
    throw(MrMattException('MrMatt not found...'));
  }  
  void moveTile(TileMove? tileMove) {
    if (tileMove != null) {
      cell(tileMove.rowStart,tileMove.colStart).setEmpty();
      cell(tileMove.rowEnd,tileMove.colEnd).setTileType(tileMove.tileTypeEnd);
      }
  }
}

class TileMove {
  final int rowStart;
  final int colStart;
  final int rowEnd;
  final int colEnd;
  final TileType tileTypeEnd;
  TileMove({required this.rowStart, required this.colStart, 
            required this.rowEnd, required this.colEnd, required this.tileTypeEnd});
  @override
  String toString()=> 'move ($rowStart,$colStart) to ($rowEnd,$colEnd): $tileTypeEnd';  
}
class TileMoves {
  bool get isEmpty =>_tileMoves.isEmpty;
  bool get isNotEmpty =>_tileMoves.isNotEmpty;
  int get length =>_tileMoves.length;
  final Queue<TileMove> _tileMoves = Queue<TileMove>();
  void push(int rowStart, int colStart, int rowEnd, int colEnd, TileType tileTypeEnd) {
    _tileMoves.addLast(TileMove(rowStart:rowStart, colStart:colStart, 
                              rowEnd:rowEnd, colEnd:colEnd, tileTypeEnd: tileTypeEnd));
  }
  void add(TileMoves tileMoves) {
    for (TileMove tileMove in tileMoves._tileMoves) {
      _tileMoves.addLast(tileMove);
    }
  }
  TileMove? pop() =>_tileMoves.isNotEmpty?_tileMoves.removeFirst(): null;
  void clear() =>_tileMoves.clear();
  TileMove? get first=>_tileMoves.first;
  TileMove? get last=>_tileMoves.last;
}
