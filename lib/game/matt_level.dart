import "package:flutter/foundation.dart";

import "matt_grid.dart";

enum Rating {unknown, easy, moderate, hard, tough}
class MattLevel {
  int level  = 0;
  String title = "";
  String checkLine = "";
  Grid grid = Grid();
  MattLevel(this.level, this.title);
  void dump(){
    if (kDebugMode) {
      print('Level: $level    title: $title');
      grid.dump();
      print('Checkline: $checkLine');
    }
  }
}
