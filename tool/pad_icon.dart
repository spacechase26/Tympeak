import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('icon_source.png').readAsBytesSync())!;

  const out = 1024;
  const scale = 0.62;
  final inner = (out * scale).round();

  final resized = img.copyResize(src, width: inner, height: inner, interpolation: img.Interpolation.cubic);

  final canvas = img.Image(width: out, height: out, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(10, 10, 26, 255));
  final offset = ((out - inner) / 2).round();
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  File('icon_foreground.png').writeAsBytesSync(img.encodePng(canvas));
  print('Wrote icon_foreground.png (${out}x$out, inner ${inner}px)');
}
