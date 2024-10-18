import 'dart:async';
import 'dart:io';
import 'dart:isolate';
/* 
  sending (text) file write tasks to an isolate for handling
  this should enable the main process to quickly continue
  without worrying about the writing
  the idea is to use this in logging.

example code:

void main() async {
  AsyncFileWriter logger = await AsyncFileWriter.create('testing321.log');
  logger.write('Something');
  logger.write('in the way you move');
  logger.close();
}
*/

class AsyncFileWriter{
  late final _IsolatedFile _asFile;
  late final File file;
  AsyncFileWriter._create();
  static Future<AsyncFileWriter> create(String filename, [String? message]) async {
    AsyncFileWriter result = AsyncFileWriter._create();
    result.file = File(filename);
    if (message!=null)
    {result.file.writeAsStringSync(message, flush: true);}
    result._asFile = await _IsolatedFile.spawn();
    return result;
  }
  void write(String s) {
    _asFile._write(file, s);
  }
  void close() {
    _asFile.close();
  }
}


class _IsolatedFile {
  // adapted from dart docs Isolates examples
  static const String shutDownMessage = '%_ShutDown_%';
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;  
  bool _closed = false;

  _IsolatedFile._(this._responses, this._commands) {
    _responses.listen(_handleResponsesFromIsolate);
  }
  Future<Object?> _write(File file, String message) async {
    if (_closed) throw StateError('Closed'); 
    final completer = Completer<Object?>.sync(); 
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send((file,id,message));
    return await completer.future;    
    
  }
  static Future<_IsolatedFile> spawn() async {
   // Create a receive port and add its initial message handler.
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        commandPort)
      );
    };
    try {
      await Isolate.spawn(_startRemoteIsolate, (initPort.sendPort));
    } on Object {
      initPort.close();
      rethrow;
    }
    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;
    return _IsolatedFile._(receivePort, sendPort);
  }
  void _handleResponsesFromIsolate(dynamic message) {
    final (int id, Object? response) = message as (int, Object?);
    final completer = _activeRequests.remove(id)!;
    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response);
    }
    if (_closed && _activeRequests.isEmpty) _responses.close();    
  }
  static void _handleCommandsToIsolate(ReceivePort receivePort, SendPort sendPort) async {
    receivePort.listen((message) async {
      if (message == shutDownMessage) {
        receivePort.close();
        return;
      }      
      final (File file, int id, String msg) = message as (File, int, String);
      try {
        file.writeAsStringSync('$msg\n', mode:FileMode.append, flush:true);
        sendPort.send((id, msg));
      } catch (e) {
        sendPort.send((id, RemoteError(e.toString(), '')));
      }
    }); 
  }
  static void _startRemoteIsolate(SendPort sendPort) {
   final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, sendPort);
  }
  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send(shutDownMessage);
    }
  }
}
