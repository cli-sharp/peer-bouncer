import Compression

extension Data {
    func gunzipped() -> Data? {
        guard !self.isEmpty else { return nil }
        
        return self.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = srcPtr.baseAddress else { return nil }
            
            // Allocate destination buffer (start with 4x input size, grow if needed)
            let dstBufferSize = 64 * 1024
            var dstBuffer = [UInt8](repeating: 0, count: dstBufferSize)
            
            var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1).pointee
            defer { compression_stream_destroy(&stream) }
            
            var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status != COMPRESSION_STATUS_ERROR else { return nil }
            
            stream.src_ptr = srcBase.assumingMemoryBound(to: UInt8.self)
            stream.src_size = self.count
            
            var output = Data()
            repeat {
                stream.dst_ptr = &dstBuffer
                stream.dst_size = dstBufferSize
                
                status = compression_stream_process(&stream, 0)
                
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let written = dstBufferSize - stream.dst_size
                    if written > 0 {
                        output.append(&dstBuffer, count: written)
                    }
                default:
                    return nil
                }
            } while status == COMPRESSION_STATUS_OK
            
            return output
        }
    }
}

