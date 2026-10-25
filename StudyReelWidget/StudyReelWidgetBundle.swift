//
//  StudyReelWidgetBundle.swift
//  StudyReelWidget
//
//  Created by Ibuki Nagase on 2025/12/18.
//

import WidgetKit
import SwiftUI

@main
struct StudyReelWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyReelWidget()
        StudyLiveActivity()
        StudyStartControl()
    }
}
