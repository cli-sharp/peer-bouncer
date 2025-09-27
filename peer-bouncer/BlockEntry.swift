import SwiftUI

struct BlockEntry: Identifiable {
    enum Kind { case ipv4, ipv6 }
    let id = UUID()
    let raw: String
    let normalized: String
    let kind: Kind
}