import 'package:flutter/material.dart';
// ignore: unused_import
import 'game/matt_game.dart';
import 'game/matt_grid.dart';
import 'game/matt_file.dart';
// ignore: unused_import
import 'game/matt_level.dart';
// ignore: unused_import
import 'log.dart';

const String defaultImageStyle = 'large/Apples';
// enum TileType {empty,grass,wall,stone,food,box1,box2,box3,bomb,mrMatt,loser}
const Map<TileType,String> mattImages = {
      TileType.empty:'0-empty.bmp', TileType.grass:'1-grass.bmp', TileType.wall:'2-wall.bmp',
        TileType.stone:'3-stone.bmp',TileType.food:'4-food.bmp',
        TileType.box1:'5-box1.bmp',TileType.box2:'6-box2.bmp',TileType.box3:'7-box3.bmp',
        TileType.bomb:'8-bomb.bmp',TileType.mrMatt:'9-matt.bmp',TileType.loser:'a-loser.bmp',};


class MattAssets {
  late Map<TileType,Image> _images;
  MattAssets([String imageStyle=defaultImageStyle]) {
    _images={};
    for (TileType tileType in TileType.values) {
      _images[tileType] = Image.asset('img/$imageStyle/${mattImages[tileType]}');
    }
  }
  Image? getImage(TileType imgType)=>_images[imgType];
}

class MattTileWidget extends StatefulWidget {  
  final MattAssets assets;
  final Tile tile;
  final Function(Tile)? tileTapped;
  const MattTileWidget({super.key, required this.tile, required this.assets, this.tileTapped});

  @override
  MattTileState createState() => MattTileState();
}

class MattTileState extends State<MattTileWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: (){
       if (widget.tileTapped != null) 
          {widget.tileTapped!(widget.tile);}
       }, 
       child: SizedBox(width:24, height: 24, child: widget.assets.getImage(widget.tile.tileType)));
  }
}

class MattGridWidget extends StatefulWidget{
  final MattAssets assets;
  final Grid grid;
  final Function(Tile)? tileTapped;
  const MattGridWidget({super.key, required this.assets, required this.grid, this.tileTapped});

  @override
  MattGridState createState() => MattGridState();
}

class MattGridState extends State<MattGridWidget> {
  Column buildColumn (int col) {
    List<MattTileWidget> children = [];
    for (int row in GridConst.rowRange()) {
      children.add(MattTileWidget(tile: widget.grid.cell(row,col), assets: widget.assets, tileTapped: widget.tileTapped,));
    }
    return Column(children:children);
  }
  Widget buildGrid() {
    List<Column> columns = [];
    for (int col in GridConst.colRange()) {
      columns.add(buildColumn(col));
    }
    return Row(children: columns);
  }
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color:Colors.amber, border: Border.symmetric(),borderRadius: BorderRadius.all(Radius.circular(6))),
                    child:buildGrid());
  }

}

class MattGameLevelWidget extends StatefulWidget{
  final MattAssets assets;
  final MattFile? file;
  final Grid? grid;
  final Function(Tile)? tileTapped;
  // final Function(BuildContext) loadFile;
  const MattGameLevelWidget({super.key, required this.assets, 
          // required this.loadFile,  
          this.file, this.grid, this.tileTapped});
  @override
  MattFileState createState() =>MattFileState();
}
class MattFileState extends State<MattGameLevelWidget>  {
  bool _fileLoaded() =>widget.file != null && widget.file!.isNotEmpty();
  bool _levelSelected() =>widget.grid!=null;  

  @override
  Widget build(BuildContext context) {
    if (_fileLoaded()) {
      return _buildLoaded(context);
    }
    throw(MrMattException('unexpected: no file loaded.'));
  }
  Widget _buildLoaded(BuildContext context) {
    assert (_fileLoaded() && _levelSelected());
    return Center(child: MattGridWidget(assets: widget.assets, grid:widget.grid!, tileTapped:widget.tileTapped));
  }  
}

class MattLevelSelector extends StatefulWidget {
  final MattFile? file;
  final Function(int level)?levelSelected;
  const MattLevelSelector({super.key, this.file, this.levelSelected}); 

  @override
  State<StatefulWidget> createState() => _MattLevelState();
}

class _MattLevelState extends State<MattLevelSelector>{
  @override
  Widget build(BuildContext context) {
    return 
      Row(children: _getLevelButtons(context),
      );
  }

  Widget _getLevelButton(int level, bool enabled) {
    return ElevatedButton(onPressed: enabled ? () { widget.levelSelected!(level);} : null, child: Text((level+1).toString()));
  }
  List<Widget> _getLevelButtons(context) {
    List<Widget> result = [];
    if (widget.file == null) {
      result.add(const Text('<No game file loaded>'));
    }
    else if (widget.file!.nrLevels == 0) {
      result.add(Text('<Game file ${widget.file!.title} has no levels>'));
    }
    else{
      for (int level = 0; level < widget.file!.nrLevels; level++){
        result.add(_getLevelButton(level, widget.file!.levels[level].accessible));
      }          
    }
    return result;
  }
}