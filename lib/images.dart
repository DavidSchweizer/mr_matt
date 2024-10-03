import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'game/matt_grid.dart';

class TileImageType {
  final String size;
  final String flavor;
  TileImageType(this.size,this.flavor);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) 
      {return true;}
    return (other is TileImageType) ? 
    other.size == size && other.flavor==flavor :
    false;    
  }  
  @override
  int get hashCode => size.hashCode ^  flavor.hashCode;
  @override
  String toString() =>'$size $flavor';
}
class MattTileConst {
  static String defaultSize = 'medium';
  static String defaultFlavor = 'Apples';
  static TileImageType defaultImageType = TileImageType(defaultSize,defaultFlavor);
  static Map<String,Map<String,dynamic>> sizes = {
    'small': {'size':16, 'flavors': ['Apples', 'Carrots', 'Hamburgers', 'Pumpkins']}, 
    'medium':{'size': 24, 'flavors':['Apples', 'Hamburgers', 'Mushrooms', 'Pumpkins']}, 
    'large': {'size': 32, 'flavors':['Apples', 'Hamburgers', 'Mushrooms', 'Pumpkins', 'Tomatoes']}, 
    'huge': {'size': 40, 'flavors':['Apples', 'Hamburgers', 'Mushrooms', 'Pumpkins', 'Tomatoes']},
  };
  static bool isValidSize(String size)=>sizes.keys.contains(size);
  static bool isValidFlavor(String size, String flavor)=>isValidSize(size) && sizes[size]!['flavors'].contains(flavor);
  static Map<TileType,String> filenames = {
         TileType.empty:'0-empty.bmp', TileType.grass:'1-grass.bmp', TileType.wall:'2-wall.bmp',
         TileType.stone:'3-stone.bmp',TileType.food:'4-food.bmp',
         TileType.box1:'5-box1.bmp',TileType.box2:'6-box2.bmp',TileType.box3:'7-box3.bmp',
         TileType.bomb:'8-bomb.bmp',TileType.mrMatt:'9-matt.bmp',TileType.loser:'a-loser.bmp',};
  static String imageFilename(String size, String flavor, TileType tileType) =>'img/$size/$flavor/${filenames[tileType]}';
  static Size normalizedSize(double width, [double? height]) {    
    height??=width/GC.aspectRatio;
    double boxSize = min((width/GC.mattWidth.toDouble()), (height/GC.mattHeight.toDouble()));
    double w = (GC.mattWidth * boxSize).toDouble();
    double h = (GC.mattHeight * boxSize).toDouble();
    return (((width - w)/width).abs() > ((height-h)/height).abs()) ? Size(w * width/w, h):Size(w, h*height/h);
  }
}
typedef MTC = MattTileConst;
class TileImageLoader {
  late TileImageType imageType;
  late int boxWidth;
  final Map<TileType,ui.Image> images = {};  
  TileImageLoader(this.imageType){
    assert(MTC.isValidSize(imageType.size) && MTC.isValidFlavor(imageType.size, imageType.flavor));
    boxWidth = MTC.sizes[imageType.size]!['size'];
  }
  Future<bool> imageLoader(int boxWidth) async {
    for (TileType tileType in TileType.values) {
      images[tileType]??=await _getUiImage(MTC.imageFilename(imageType.size,imageType.flavor, tileType), boxWidth);
    }
    return isLoaded;
  }
  Future<ui.Image> _getUiImage(String imageFilename, int boxWidth) async {
    final ByteData assetImageByteData = await rootBundle.load(imageFilename);
    final codec = await ui.instantiateImageCodec(
      assetImageByteData.buffer.asUint8List(),
      targetHeight: boxWidth,
      targetWidth: boxWidth,
    );
    return (await codec.getNextFrame()).image.clone(); 
  }
  bool get isLoaded {
    for (TileType tileType in TileType.values) {
      if (images[tileType]==null) {return false;}
    }
    return true;
  }
}
class MattTileImages {
  final Map<TileType,ui.Image> images = {};  
  late TileImageType? _imageType;
  TileImageType? get imageType=>_imageType;
  set imageType(TileImageType? value) {
    assert (value != null);
    if (_imageType != null && value == imageType) { return; }
    _imageType = value;
    images.clear();  
    isLoaded = false;
    boxWidth = 0;
  }
  bool isLoaded = false;
  int boxWidth = 0;
  ui.Image? getImage(TileType tileType)=>isLoaded ? images[tileType] : null;
  bool isAlreadyLoaded(int boxWidth, TileImageType? selectType)=>isLoaded && imageType==selectType && boxWidth == this.boxWidth;
  Future<bool>loadImages(int boxWidth, [TileImageType? selectType]) async {
    if (!isAlreadyLoaded(boxWidth, selectType)) {
      TileImageLoader loader = TileImageLoader(selectType??MTC.defaultImageType);
      await loader.imageLoader(boxWidth);
      if (loader.isLoaded) {
        images.addAll(loader.images);
        isLoaded = true;
        this.boxWidth = boxWidth;
        _imageType = selectType;
      }
    }
    return isLoaded;
  }
}
