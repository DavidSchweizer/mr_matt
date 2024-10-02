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
    file.writeAsStringSync('STARTING RUN $nowString\n\n', flush: true);
  }

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      // NOTE: this can slow operations down considerably
      // however, if we do it async we need to do something to preserve order properly
    }
  }
}

void logInfo(String line) {
  logger.i(line);  
}

void logDebug(String line) {
  logger.d(line);
}

String nowString([String format='HH:mm:ss'])=> DateFormat(format).format(DateTime.now());