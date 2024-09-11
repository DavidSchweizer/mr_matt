import 'dart:io';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

var logger = Logger(
  output: FileOutput(),
  printer: PrefixPrinter(PrettyPrinter(colors:false, printEmojis: false, methodCount:0, dateTimeFormat:DateTimeFormat.none, noBoxingByDefault: true)),
);

class FileOutput extends LogOutput {
  final file = File('mrmatt.log');
  FileOutput() :super() {
    String nowString = DateFormat("dd-MM-yyyy HH:mm:ss").format(DateTime.now());
    file.writeAsStringSync('STARTING RUN $nowString\n\n');
  }

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    }
  }
}

void logInfo(String line) {
  logger.i(line);  
}

void logDebug(String line) {
  logger.d(line);
}