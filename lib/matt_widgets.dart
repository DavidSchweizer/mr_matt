import 'package:flutter/material.dart';

import 'game/matt_file.dart';
import 'game/matt_grid.dart';
import 'game_grid.dart';
import 'images.dart';
class MattGameLevelWidget extends StatefulWidget{
  // final MattAssets assets;
  final MattTileImages images;
  final TileImageType imageType;
  final MattFile? file;
  final Grid? grid;
  final double width;
  final Function(Tile?)? onTapUpCallback;
  // final Function(BuildContext) loadFile;
  const MattGameLevelWidget({super.key, required this.images, required this.imageType,
          required this.width,  required this.file, this.grid, this.onTapUpCallback});
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
    return Center(child: GameGridWidget(images: widget.images, grid:widget.grid!, 
    tileImageType: widget.imageType,
    width: widget.width,
            onTapUpCallback:widget.onTapUpCallback));
  }  
}

class MattLevelSelector extends StatefulWidget {
  final MattFile? file;
  final Function(int level)?levelSelected;
  final int? selected;
  const MattLevelSelector({super.key, this.file, this.levelSelected, this.selected}); 

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

  Widget _getLevelButton(int level, bool enabled, bool selected) {
    if (selected) {
      return ElevatedButton(onPressed: enabled ? () { widget.levelSelected!(level);} : null, 
                            style: ElevatedButton.styleFrom(side: const BorderSide(color: Colors.black54, width:2)),
                            child: Text((level+1).toString())
                          );
    }
    else {
      return ElevatedButton(onPressed: enabled ? () { widget.levelSelected!(level);} : null, 
                            child: Text((level+1).toString())
                          );
    }
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
        result.add(_getLevelButton(level, widget.file!.levels[level].accessible, level==widget.selected));
      }          
    }
    return result;
  }
}