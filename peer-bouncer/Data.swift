import Foundation

extension Data {
    func gunzipped() -> Data? {
        return try? (self as NSData).decompressed(using: .zlib) as Data
    }
}
