//
//  MetroWidgetBundle.swift
//  MetroWidget
//
//  Created by Jaime Ferreira on 16/07/2026.
//

import WidgetKit
import SwiftUI

@main
struct MetroWidgetBundle: WidgetBundle {
    var body: some Widget {
        MetroWidget()
        // MetroWidgetControl() — Xcode's "Start Timer" Control Centre template,
        // not part of this app. Unregistered so it doesn't ship.
    }
}
