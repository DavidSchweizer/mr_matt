import 'package:path/path.dart' as p;

String pathWithExtension(String filename, String extension) {
  return '${p.withoutExtension(filename)}$extension';
}
