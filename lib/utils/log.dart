import 'dart:io';

import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:path/path.dart' as p;

import 'async_file.dart';

Logger? logger;
AsyncFileWriter? _closeit;

String nowString([String format='HH:mm:ss'])=> DateFormat(format).format(DateTime.now());
void initLogging([String filename='mr_matt.log', String message='Starting Mr. Matt logging']) async {
  Directory logDirectory = await pp.getApplicationSupportDirectory();
  filename = p.join(logDirectory.path, filename);
  print(filename); 
  _closeit = await AsyncFileWriter.create(filename, '$message: ${nowString()}');
  logger = Logger(output: AsyncFileOutput(_closeit!),
      printer: PrefixPrinter(PrettyPrinter(colors:false, printEmojis: false, methodCount:0, 
            dateTimeFormat:DateTimeFormat.none, noBoxingByDefault: true)),
      );
}
void closeLogging() {
  // is not called, todo figure out how to do this!
  if (_closeit is AsyncFileWriter) {
    _closeit!.write('Closing log at ${nowString()}');
    _closeit!.close();
  }
}
class AsyncFileOutput extends LogOutput {
  final AsyncFileWriter _asFile;
  AsyncFileOutput(this._asFile): super();  
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      _asFile.write(line);
    }
  }
}

void logInfo(String line) {
  logger?.i(line);  
}

void logDebug(String line) {
  logger?.d(line);
}

