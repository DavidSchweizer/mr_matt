import "matt_grid.dart";

enum Rating {unknown, easy, moderate, hard, tough}
class MattLevel {
  int level  = 0;
  String title = "";
  String checkLine = "";
  Grid grid = Grid();
  bool accessible = false;
  MattLevel(this.level, this.title, this.accessible);
}
