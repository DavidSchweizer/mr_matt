import 'package:flutter/material.dart';

import 'widgets/dialogs.dart';
import 'log.dart';
import 'game/matt_file.dart';
import 'game/matt_level.dart';

double aspect = 432/744; // bitmap size of background pic

  class MattSelectFileTile extends StatefulWidget {
    final MattFiles? files;    
    final MattFile? initialFile;
    final void Function(MattFile? file)? fileChanged;
    const MattSelectFileTile({super.key, this.files, this.initialFile, this.fileChanged});
    @override
    State<MattSelectFileTile> createState()=>_MattSelectFileState();
    }

  class _MattSelectFileState extends State<MattSelectFileTile> {
    // final ScrollController _scrollController=ScrollController();
    MattFile? _selectedFile;
    Map<Rating,bool> ratings = {Rating.easy: true, Rating.moderate: true, Rating.hard: true, Rating.tough: true, Rating.unknown: false};

    MattFile? _findSelectedFile() {
      if (widget.files == null) 
        {return null;}
      else {        
        _selectedFile = widget.initialFile;
        if (_selectedFile != null) {
          if (ratings[_selectedFile!.rating]??false) {
            return _selectedFile;
          }
          else { _selectedFile = null;}
        }
        if (_selectedFile == null) {
          for (MattFile file in widget.files!.mattFiles) {
            if (ratings[file.rating]??false) {
              return file;
            }
          } 
        }
      }
      return null;
    }

    Widget _getRating(Rating rating) {
      return SwitchListTile(dense: true, title: Text(rating.name),value: ratings[rating]??false, 
                onChanged: (bool value) 
                { logDebug('Rating: ${rating.name} value: $value'); 
                  setState((){
                    ratings[rating]=value;
                    });
                },);
    }
    List<DropdownMenuEntry<MattFile>> getList(MattFiles? files) {
      Map<Rating,Color> ratingColors = 
        {Rating.easy: Colors.green,
        Rating.moderate: Colors.grey,
        Rating.hard: Colors.orange,
        Rating.tough: Colors.red};
  
      return files!.mattFiles
        .where((file)=>ratings[file.rating]??false)
        .map<DropdownMenuEntry<MattFile>>(
                              (MattFile file) {
                        return DropdownMenuEntry<MattFile>(
                          value: file,
                          label: file.title,
                          labelWidget: 
                            RichText(
                              text: TextSpan(text:file.title,
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                      TextSpan(text: '   ${file.rating.name}', 
                                      style: TextStyle(color: ratingColors[file.rating])),
                                      TextSpan(text: ' (${file.levels.length} levels)', 
                                      style: const TextStyle(fontStyle: FontStyle.italic)),
                                      ])
                                    )
                                  )                                
                              ;}).toList();
    }

    Widget _getRatingsBox() {
      return Opacity(
        opacity: .75,
        child: Container(
                  width: 300,
                  // height: 300,
                  decoration: BoxDecoration(color: Colors.amber[200],
                  borderRadius: const BorderRadius.all(Radius.circular(20)),),
                  child:
                    Column(
                    children: [
                      _getRating(Rating.easy),
                      _getRating(Rating.moderate),
                      _getRating(Rating.hard),
                      _getRating(Rating.tough),
                    ]
                    ),                                  
                ),
      );
    }

    Widget _getLoadGameBox(void Function(MattFile? file)? fileChanged){
      List<DropdownMenuEntry<MattFile>> fileList = getList(widget.files);
      if (fileList.isNotEmpty) {
        return Opacity(
              opacity: .75, 
              child: 
                Container(
                  decoration: BoxDecoration(color: Colors.amber[400],
                      border: Border.all(color: Colors.amber[700]!, width: 4,)),
                  child: DropdownMenu<MattFile>(
                    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.amber[300]),
                    dropdownMenuEntries: fileList,
                    initialSelection: _selectedFile,
                    onSelected: (MattFile? file) 
                    { setState(() {_selectedFile = file; }); 
                      widget.fileChanged!(file); 
                    }
                  ),
                ));
      }
      else {
        return Opacity(
              opacity: .75, 
              child: 
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber[400],
                      border: Border.all(color: Colors.amber[700]!, width: 4,)
                      ),
                  child: const Text('No games with this selection'),));                
      }
    }

    @override
    Widget build(BuildContext context) {
      const double sizeOfBox = 500;
      _selectedFile = _findSelectedFile();
      // widget.fileChanged!(_selectedFile);
      return Center(child: 
                    Container(
                      width: sizeOfBox,
                      height: sizeOfBox * aspect,                                                
                      decoration: BoxDecoration(
                      image: const DecorationImage(image: AssetImage('img/mm_pic.jpg'),),                          
                      border: Border.all(color: Colors.black),
                      ),                        
                      child: 
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            _getRatingsBox(),
                            // _getLoadGameTextBox(),
                            const SizedBox(height: 20),
                            _getLoadGameBox(widget.fileChanged),
                            const SizedBox(height: 20)
                  ]
                )));    
    }
  }

  class MattSelectFileDialog extends StatefulWidget {
    final MattFiles? files;
    final MattFile? initialFile;
    const MattSelectFileDialog({super.key, this.files, this.initialFile});
    
    @override
    State<StatefulWidget> createState() =>_MattSelectFileDialogState();
  }
  
  class _MattSelectFileDialogState extends State<MattSelectFileDialog> {
    MattFile? selectedFile;
    void callBackFile(MattFile? file) {
      selectedFile = file;
      logDebug('file changed: $file');
    }
    @override
    Widget build(BuildContext context) {
      return Dialog(backgroundColor: Colors.amber[100], 
                    child: SizedBox(
                      width: 500,
                      height: 500*aspect + 80,
                      child: Center(
                        child: Column(
                          children: [const SizedBox(height:20), 
                          MattSelectFileTile(files:widget.files, initialFile: widget.initialFile, fileChanged: callBackFile),
                          const SizedBox(height:16),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                          children:[MattDialogButton(onPressed: () {
                                    Navigator.of(context).pop(selectedFile);
                              },
                              label: "load",
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
                        ]),
                      ),
                    ),
                    );
    }
  }
  Future <MattFile?> selectFileFromDialog(BuildContext context, MattFiles files, MattFile? initialFile) async {

    try {
      MattFile? result = await showDialog(context: context, 
                        builder: (BuildContext context) {
                          return MattSelectFileDialog(files: files, initialFile: initialFile);
                        });  
      return result;
    }
    on Exception catch (e) {
      logDebug('gotcha $e');
      return null;
    }
  }
