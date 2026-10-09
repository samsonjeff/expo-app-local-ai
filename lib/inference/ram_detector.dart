import 'dart:io';
import '../models/inference.dart';

class RamDetector {
  static Future<HardwareProfile> detectProfile() async {
    int totalRamMb = 4096;
    int availableRamMb = 2048;

    try {
      if (Platform.isAndroid) {
        final memInfoFile = File('/proc/meminfo');
        if (await memInfoFile.exists()) {
          final lines = await memInfoFile.readAsLines();
          for (final line in lines) {
            if (line.startsWith('MemTotal:')) {
              final kb = _extractKb(line);
              totalRamMb = kb ~/ 1024;
            } else if (line.startsWith('MemAvailable:')) {
              final kb = _extractKb(line);
              availableRamMb = kb ~/ 1024;
            }
          }
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        totalRamMb = 8192;
        availableRamMb = 4096;
      }
    } catch (_) {
      // Safe fallback
      totalRamMb = 4096;
      availableRamMb = 2048;
    }

    final tier = (totalRamMb >= 6000) ? HardwareTier.high : HardwareTier.low;
    final recommendedThreads = Platform.numberOfProcessors > 2 ? 4 : 2;

    return HardwareProfile(
      totalRamMb: totalRamMb,
      availableRamMb: availableRamMb,
      tier: tier,
      recommendedThreads: recommendedThreads,
      recommendedContextSize: tier == HardwareTier.high ? 8192 : 4096,
    );
  }

  static int _extractKb(String line) {
    final match = RegExp(r'\d+').firstMatch(line);
    return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
  }
}
