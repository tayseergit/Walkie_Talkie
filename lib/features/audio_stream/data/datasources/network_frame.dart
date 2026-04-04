import 'dart:convert';
import 'dart:typed_data';

class NetworkFrame {
  final Map<String, dynamic> header;
  final Uint8List payload;

  NetworkFrame({required this.header, required this.payload});

  /// Encodes header and payload perfectly into a strict bytes pipeline array structure
  /// Structure: [Header Length: 4 bytes] + [Header JSON Bytes] + [Payload Bytes]
  Uint8List encode() {
    final headerBytes = utf8.encode(jsonEncode(header));
    final headerBytesList = Uint8List.fromList(headerBytes);
    
    final lengthBytes = ByteData(4);
    lengthBytes.setInt32(0, headerBytesList.length, Endian.big);

    final builder = BytesBuilder(copy: false);
    builder.add(lengthBytes.buffer.asUint8List());
    builder.add(headerBytesList);
    builder.add(payload);

    return builder.toBytes();
  }
}

class TcpStreamParser {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  
  /// Continuously pushes incoming raw TCP socket data parsing complete dynamic frames sequentially 
  List<NetworkFrame> parseIncomingChunks(Uint8List newChunk) {
    _buffer.add(newChunk);
    List<NetworkFrame> decodedFrames = [];

    while (true) {
      final currentBytes = _buffer.toBytes();
      
      // Minimum length bytes check internally mapped natively
      if (currentBytes.length < 4) break;

      final lengthData = ByteData.sublistView(currentBytes, 0, 4);
      final headerLength = lengthData.getInt32(0, Endian.big);

      // We need entirely enough bytes perfectly fitting the entire frame natively
      if (currentBytes.length < 4 + headerLength) break;

      final headerBytes = currentBytes.sublist(4, 4 + headerLength);
      final payloadBytesOffset = 4 + headerLength;
      
      Map<String, dynamic> header;
      try {
        header = jsonDecode(utf8.decode(headerBytes));
      } catch (e) {
        // If JSON is entirely corrupted, safely purge buffer completely preventing deadlock cascades natively
        _buffer.clear();
        break;
      }
      
      // Determine if payload length is actively specified in header structurally cleanly 
      int payloadLength = header['payloadLen'] ?? 0;

      if (currentBytes.length < payloadBytesOffset + payloadLength) {
        break; // Wait for remainder dynamically natively
      }
      
      final payload = currentBytes.sublist(payloadBytesOffset, payloadBytesOffset + payloadLength);
      
      decodedFrames.add(NetworkFrame(header: header, payload: payload));

      // Successfully processed exactly this chunk, trim the native buffer perfectly cleanly
      final remainingBytesOffset = payloadBytesOffset + payloadLength;
      final remainingBytes = currentBytes.sublist(remainingBytesOffset);
      
      _buffer.clear();
      _buffer.add(remainingBytes);
    }

    return decodedFrames;
  }
}
