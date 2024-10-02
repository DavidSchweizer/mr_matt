
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../game/matt_grid.dart';
import '../game/matt_level.dart';
import '../images.dart';

int random(int start, int end) {
  final random = Random();
  return start + random.nextInt(end - start);  
}
TileType getRandomTile(){
  const Map<int,TileType> mapToTile = 
  {0:TileType.empty, 1:TileType.stone, 2:TileType.wall, 3:TileType.bomb, 4:TileType.box1, 5:TileType.box2, 6:TileType.box3, 7:TileType.grass, 8:TileType.food};
  return mapToTile[random(0,mapToTile.length)]??TileType.empty;
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
TileImageType randomTileImageType(){
  String size = MTC.sizes.keys.toList()[random(0,MTC.sizes.keys.length)];
  List<String> flavors = MTC.sizes[size]!['flavors'];
  String flavor = flavors[random(0,flavors.length)];
  return TileImageType(size, flavor);
}

void dumpGrid(Grid grid) {
  if (kDebugMode) {
    stdout.write('  ');
    for (int col in GC.colRange()){
      stdout.write(col.toString().padLeft(3,' '));
    }
    stdout.write('\n');
    for (int row in GC.rowRange()){
      stdout.write('${row.toString().padRight(2,' ')}: ');
      for (int col in GC.colRange()){
        stdout.write(grid.cell(row,col).dumpStr());
        if (!GC.isRight(col)) {
          stdout.write(' ');
        }
      }
      stdout.write('\n');
    }
  }
}
void dumpLevel(MattLevel level) {
  if (kDebugMode) {
    print('Level: ${level.level}    title: ${level.title}');
    dumpGrid(level.grid);
    print('Checkline: ${level.checkLine}');
  }
}
