//
//  BlockEntry.swift
//  peer-bouncer
//
//  Created by Christian Linse on 20.09.25.
//


import SwiftUI

struct BlockEntry: Identifiable {
    enum Kind { case ipv4, ipv6 }
    let id = UUID()
    let raw: String
    let normalized: String
    let kind: Kind
}