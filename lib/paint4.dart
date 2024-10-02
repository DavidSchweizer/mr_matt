import 'dart:async';
import 'package:flutter/material.dart'  as flutter;
import 'package:flutter/material.dart';
import 'game/matt_grid.dart';
import 'images.dart';
import 'dart:ui' as ui;


class MattGridPaintGeometry {
  Map<int,double> rowTop = {};
  Map<int,double> colLeft = {};
  double _boxSize = 0;
  double _currentBoxSize = 0;
  double get boxSize =>_boxSize;
  set boxSize(double value) {
    _boxSize=value;
    if (_currentBoxSize != boxSize) {
      _initBoxes(boxSize);
    }
  }
  double getLeftCol(int col)=>colLeft[col]!.toDouble();
  double getTopRow(int row)=>rowTop[row]!.toDouble();
  void _initBoxes(double boxSize) {
    if (rowTop.isNotEmpty && colLeft.isNotEmpty && _currentBoxSize == boxSize){
      return;
    }
    for (int row in GC.rowRange()){
      rowTop[row] = row * boxSize;
    }
    for (int col in GC.colRange()){
      colLeft[col] = col * boxSize;
    }
    _currentBoxSize = boxSize;
  }  
  RowCol? getRowCol(Offset position) {
    if (boxSize == 0) {return null;}
    int row = (position.dy/boxSize).floor();
    int col = (position.dx/boxSize).floor();
    return (RowCol.isValid(row, col)) ? RowCol(row,col) : null;
  }  
}

class MattTilePainter extends flutter.CustomPainter {
  final ui.Image image;
  MattTilePainter(this.image);
  @override
  void paint(flutter.Canvas canvas, flutter.Size size) {
    flutter.paintImage(canvas:canvas, rect: ui.Rect.fromLTWH(0,0,size.width,size.height), 
              fit:BoxFit.contain, alignment: Alignment.bottomRight, image:image); 
  }
  @override
  bool shouldRepaint(MattTilePainter oldDelegate) {
    return oldDelegate.image != image;
  } // could and should be improved I guess
}

class MattTileWidget extends flutter.StatelessWidget {
  final Tile tile;
  final double boxSize;
  final MattTileImages images;
  const MattTileWidget({super.key, required this.tile, required this.boxSize, required this.images});
  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.CustomPaint(size: Size(boxSize,boxSize),
        painter:MattTilePainter(images.getImage(tile.tileType)!));
  }
}
class MattGridWidget2 extends flutter.StatelessWidget {
  final Grid grid;
  final MattTileImages images;
  final TileImageType tileImageType; 
  final double width;
  final Function(Tile?)? onTapUpCallback;
  MattGridWidget2({super.key, required this.images, required this.grid, required this.tileImageType, 
                required this.width, this.onTapUpCallback});
  final MattGridPaintGeometry geometry = MattGridPaintGeometry();

  Future<bool> _loadImages(int boxWidth) {
    return images.loadImages(boxWidth, tileImageType);
  }
  Widget _buildWidgets() {
    List<Row> rows = [];
    for (int row in GC.rowRange()){    
      List<Widget> columns = [];
      for (int col in GC.colRange()) {
        Tile tile = grid.cell(row,col);
        columns.add(MattTileWidget(tile:tile, boxSize: geometry.boxSize, images: images));
      } 
      rows.add(Row(children:columns));
    }      
    return Column(children: rows);
  }
  void _tapUpHandler(TapUpDetails details) {
    RowCol? position = geometry.getRowCol(details.localPosition);
    Tile? tile = (position != null) ? grid.cell(position.row,position.col) : null;
    if (onTapUpCallback != null) {
      onTapUpCallback!(tile);
    }
  }
  @override
  flutter.Widget build(flutter.BuildContext context) {
    Size size = MTC.normalizedSize(width);
    geometry.boxSize = size.width/GC.mattWidth;
    return 
      flutter.GestureDetector(onTapUp: _tapUpHandler, behavior: HitTestBehavior.opaque,
        child: flutter.SizedBox(width: size.width,height:size.height,
          child: flutter.Container(
            alignment: Alignment.center,
            padding: const flutter.EdgeInsets.all(1),
              decoration:  flutter.BoxDecoration(color: flutter.Colors.amber, border: flutter.Border.all(),),
            width: size.width+2,
            height: size.height+2,
            child: flutter.FittedBox(child: flutter.SizedBox(width: size.width, height: size.height, 
              child:
                FutureBuilder<bool>(future: _loadImages(geometry.boxSize.round()), 
                builder:(context, snapshot) {
                if (snapshot.hasData) {                  
                  return _buildWidgets();
                }
                else {
                  return  const Center(
                          child: CircularProgressIndicator(),);
                  }
                }        
                )
            ),
          ),
              ),
        ),
      );
  }
}

