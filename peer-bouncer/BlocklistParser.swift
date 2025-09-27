import Foundation

struct BlocklistParser {
    
    static func parseBlocklistText(_ text: String) -> (entries: [BlockEntry], invalidLines: [String]) {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var entries: [BlockEntry] = []
        var invalid: [String] = []
        
        for line in lines {
            if line.isEmpty { continue }
            if line.hasPrefix("#") { continue }
            
            // Drop optional description before ":"
            let parts = line.split(separator: ":", maxSplits: 1)
            let value = parts.count == 2 ? String(parts[1]) : String(parts[0])
            
            if let normalized = normalizeCIDR(value) {
                let kind: BlockEntry.Kind = normalized.contains(":") ? .ipv6 : .ipv4
                entries.append(BlockEntry(raw: line, normalized: normalized, kind: kind))
            }
            else if let cidrs = convertRangeToCIDRs(value) {
                for c in cidrs {
                    let kind: BlockEntry.Kind = c.contains(":") ? .ipv6 : .ipv4
                    entries.append(BlockEntry(raw: line, normalized: c, kind: kind))
                }
            }
            else {
                invalid.append(line)
            }
        }
        return (entries, invalid)
    }
    
    private static func normalizeCIDR(_ s: String) -> String? {
        if s.contains("/") {
            let parts = s.split(separator: "/")
            guard parts.count == 2 else { return nil }
            let ip = String(parts[0])
            let prefixStr = String(parts[1])
            guard let prefix = Int(prefixStr) else { return nil }
            if isValidIPv4(ip) {
                return (prefix >= 0 && prefix <= 32) ? "\(ip)/\(prefix)" : nil
            } else if isValidIPv6(ip) {
                return (prefix >= 0 && prefix <= 128) ? "\(ip)/\(prefix)" : nil
            } else { return nil }
        } else {
            if isValidIPv4(s) { return s }
            if isValidIPv6(s) { return s }
            return nil
        }
    }
    
    /// Parse range like "1.2.3.4-1.2.3.200" into CIDRs
    private static func convertRangeToCIDRs(_ s: String) -> [String]? {
        let parts = s.split(separator: "-")
        guard parts.count == 2 else { return nil }
        let start = String(parts[0])
        let end = String(parts[1])
        
        if isValidIPv4(start) && isValidIPv4(end) {
            return ipv4RangeToCIDR(start: start, end: end)
        }
        // (IPv6 range support would be more complex)
        return nil
    }
    
    // MARK: - IPv4 range to CIDRs
    private static func ipv4RangeToCIDR(start: String, end: String) -> [String]? {
        guard let startInt = ipv4ToInt(start),
              let endInt = ipv4ToInt(end),
              startInt <= endInt else { return nil }
        
        var result: [String] = []
        var current = startInt
        
        while current <= endInt {
            // largest power-of-two block
            let maxSize = current & (~current - 1)
            let remaining = endInt - current + 1
            var blockSize = maxSize
            while blockSize > remaining {
                blockSize = blockSize >> 1
            }
            let prefix = 32 - Int(log2(Double(blockSize)))
            let ipStr = intToIPv4(current)
            result.append("\(ipStr)/\(prefix)")
            current += blockSize
        }
        
        return result
    }
    
    // MARK: - Helpers
    private static func ipv4ToInt(_ s: String) -> UInt32? {
        var addr = in_addr()
        guard s.withCString({ inet_pton(AF_INET, $0, &addr) }) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }
    
    private static func intToIPv4(_ val: UInt32) -> String {
        let bytes = (
            UInt8((val >> 24) & 0xff),
            UInt8((val >> 16) & 0xff),
            UInt8((val >> 8) & 0xff),
            UInt8(val & 0xff)
        )
        return "\(bytes.0).\(bytes.1).\(bytes.2).\(bytes.3)"
    }
    
    private static func isValidIPv4(_ s: String) -> Bool {
        var addr = in_addr()
        return s.withCString { inet_pton(AF_INET, $0, &addr) } == 1
    }
    
    private static func isValidIPv6(_ s: String) -> Bool {
        var addr = in6_addr()
        return s.withCString { inet_pton(AF_INET6, $0, &addr) } == 1
    }
}

