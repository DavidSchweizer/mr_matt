import 'package:flutter/material.dart';
import 'package:mr_matt/widgets/buttons.dart';
import '../utils/log.dart';
import 'game/matt_grid.dart';
import 'images.dart';


const double boxHeight = 400;
const double sizeWidth = 200;
const double flavorWidth = 350;
class MattSelectSizeWidget extends StatefulWidget {
  final String initialSize;
  final void Function(String?) callBack;
  const MattSelectSizeWidget({super.key,required this.initialSize, required this.callBack});
  @override
  State<MattSelectSizeWidget> createState()=>_MattSelectSizeState();
}
class _MattSelectSizeState extends State<MattSelectSizeWidget> {
  late String? currentSize;

  @override
  void initState() {
    currentSize = widget.initialSize;
    super.initState();
  }
  void _selectSize(String? value) {
    currentSize = value;
    widget.callBack(currentSize);
  }
  List<Widget> _getSizes() {
    List<Widget> result = [const Text('size'), const Divider()];
    for (String size in MTC.sizes.keys) {
      result.add(RadioListTile(title: Text(size), value:size, groupValue: currentSize, onChanged: _selectSize));
    }
    return result;
  }
  Widget _getSizesBox() {
    return Opacity(
      opacity: .75,
      child: SizedBox(
                      width: sizeWidth, height: boxHeight,
                      child: Column(children: _getSizes()),
                  ),                                  
              );
  }
  @override
  Widget build(BuildContext context) {
    return _getSizesBox();
  }
}

class ImageSampleWidget extends StatelessWidget{
  final MattAssetImages images;
  final double size;
  const ImageSampleWidget({super.key,required this.images, required this.size});
  @override
  Widget build(BuildContext context) {
    List<Widget> tileImages = [];
    for (TileType tileType in TileType.values.where((t)=>t!=TileType.empty)) {
      tileImages.add(SizedBox(width: size, height: size, child:FittedBox(child:images.getImage(tileType)!)));
    }
    return Row(children:tileImages);
  }
}
class MattSelectFlavorWidget extends StatefulWidget {
  final String size;
  final String initialFlavor;
  final void Function(String?) callBack;
  const MattSelectFlavorWidget({super.key,required this.size, required this.initialFlavor, required this.callBack});
  @override
  State<MattSelectFlavorWidget> createState()=>_MattSelectFlavorState();
}

class _MattSelectFlavorState extends State<MattSelectFlavorWidget> {
  late String? currentFlavor;
  final Map<String,Map<String,MattAssetImages>> allImages = {};

  @override
  void initState() {
    currentFlavor = MTC.isValidFlavor(widget.size, widget.initialFlavor)? widget.initialFlavor : MTC.defaultFlavor;
    for (String size in MTC.sizes.keys) {
      Map<String,MattAssetImages> sizeFlavors = {};
      for (String flavor in MTC.sizes[size]!['flavors']) {
        sizeFlavors[flavor] = MattAssetImages(TileImageType(size,flavor));
      }
      allImages[size] = sizeFlavors;
    }
    super.initState();
  }

  void _selectFlavor(String? value) {
    currentFlavor = value;
    widget.callBack(currentFlavor);
  }
  List<Widget> _getFlavors() {
    List<Widget> result = [const Text('flavor'), const Divider()];
    List<String> availableFlavors = MTC.isValidSize(widget.size)? MTC.sizes[widget.size]!['flavors'] : [];
    if (!availableFlavors.contains(currentFlavor)){
      currentFlavor = availableFlavors.first;
    }
    double size = 24;
    for (String flavor in availableFlavors) {
      result.add(RadioListTile(title: Text(flavor), 
                              subtitle: ImageSampleWidget(images: allImages[widget.size]![flavor]!, size: size),
                              isThreeLine: true,
                              value:flavor, groupValue: currentFlavor, onChanged: _selectFlavor));
    }
    return result;
  }
  Widget _getFlavorsBox() {
    return Opacity(
      opacity: .75,
      child: SizedBox(
                      width: flavorWidth, height: boxHeight,
                      // decoration: BoxDecoration(color: Colors.amber[100],
                      // borderRadius: const BorderRadius.all(Radius.circular(20)),),
                      child: Column(children: _getFlavors()),
                  ),                                  
    );
  }
  @override
  Widget build(BuildContext context) {
    return _getFlavorsBox();
  }
}

class MattSelectImageStyleWidget extends StatefulWidget {
  final TileImageType initialStyle;
  final Function(TileImageType) ? imageTypeChanged;
  const MattSelectImageStyleWidget({super.key, required this.initialStyle, this.imageTypeChanged});
  @override
  State<MattSelectImageStyleWidget> createState()=>_MattSelectImageStyleState();
}

class _MattSelectImageStyleState extends State<MattSelectImageStyleWidget> {
  late String? currentSize;
  late String? currentFlavor;
  void _imageTypeChanged() {
    if (widget.imageTypeChanged != null) 
    {
      widget.imageTypeChanged!(TileImageType(currentSize!, currentFlavor!));
    }
  }
  void _sizeChanged(String? value) {
    setState(() {currentSize = value;
          if (!MTC.isValidFlavor(currentSize!, currentFlavor!))
            {currentFlavor = MTC.defaultFlavor;}
    });
    _imageTypeChanged();
  }
  void _flavorChanged(String? value) {
    setState(() {currentFlavor = value;});
    _imageTypeChanged();
  }
  @override 
  void initState() {
    currentSize = widget.initialStyle.size;
    currentFlavor = widget.initialStyle.flavor;
    super.initState();
  }
  @override
  Widget build(BuildContext context) {

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [MattSelectSizeWidget(callBack: _sizeChanged, initialSize: currentSize!), 
                           MattSelectFlavorWidget(callBack: _flavorChanged, size: currentSize!, initialFlavor:currentFlavor!),  
                          ]
    );
  }
}

class MattSelectStyleDialog extends StatefulWidget {
  final TileImageType? initialStyle;
  const MattSelectStyleDialog({super.key, this.initialStyle});
  
  @override
  State<StatefulWidget> createState() =>_MattSelectStyleDialogState();
}

class _MattSelectStyleDialogState extends State<MattSelectStyleDialog> {
  TileImageType? selectedStyle;
  @override
  void initState() {
    selectedStyle = widget.initialStyle;
    super.initState();
  }
  void _imageTypeChanged(TileImageType newValue) {
    setState(() {selectedStyle = newValue;});
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(backgroundColor: Colors.amber[100], 
                  child: SizedBox(
                    width: sizeWidth+flavorWidth, height: boxHeight + 50,
                    child: Center(
                      child: Column(
                        children: [//const SizedBox(height:CSF.boxHeight), 
                        const Spacer(),
                        MattSelectImageStyleWidget(initialStyle: selectedStyle!, imageTypeChanged: _imageTypeChanged),
                        const Spacer(),
                        Row(mainAxisAlignment: MainAxisAlignment.center,
                        children:[MattDialogButton(onPressed: () {
                                  Navigator.of(context).pop(selectedStyle);
                            },
                            label: "apply",
                            icon: const Icon(Icons.check),
                            ),
                            const SizedBox(width: 20),
                          MattDialogButton(
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
                            label: "cancel",
                            icon: const Icon(Icons.cancel),
                            ), ],
                        ),
                        const Spacer(),
                      ]),
                    ),
                  ),
                  );
  }
}

Future <TileImageType?> selectStyleFromDialog(BuildContext context, TileImageType? initialStyle) async {
  try {
    TileImageType? result = await showDialog(context: context, 
                      builder: (BuildContext context) {
                        return MattSelectStyleDialog(initialStyle: initialStyle);
                      });  
    return result;
  }
  on Exception catch (e) {
    logDebug('gotcha $e');
    return null;
  }
}

