
//
//  Healthfit_Watch.swift
//  Healthfit Watch
//
//  Created by Gerald Ashby on 5/30/26.
//

import AppIntents

struct Healthfit_Watch: AppIntent {
    static var title: LocalizedStringResource { "Healthfit Watch" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
