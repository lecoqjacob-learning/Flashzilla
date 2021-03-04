//
//  Card.swift
//  Flashzilla
//
//  Created by Jacob LeCoq on 3/4/21.
//

import Foundation

struct Card: Codable, Identifiable {
    private(set) var id = UUID()
    let prompt: String
    let answer: String

    static var example: Card {
        Card(prompt: "Who played the 13th Doctor in Doctor Who?", answer: "Jodie Whittaker")
    }
}
