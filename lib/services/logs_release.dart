import 'package:flutter/foundation.dart';

/// H-04: debugPrint escribe en Logcat también en release; ahí se apaga.
void silenciarLogsEnRelease({bool release = kReleaseMode}) {
  if (release) debugPrint = (String? mensaje, {int? wrapWidth}) {};
}
