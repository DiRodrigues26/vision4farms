import 'dart:math';

/// Gerador simples de UUID v4 (sem dependência externa).
/// Usado para `client_uuid` em operações offline — garante idempotência
/// caso a operação seja reenviada após reconexão.
class UuidHelper {
  static final _random = Random();

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Setar versão (4) e variante conforme RFC 4122
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
