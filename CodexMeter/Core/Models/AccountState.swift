//
//  AccountState.swift
//  CodexMeter
//

import Foundation

enum AccountState: Equatable {
    case unknown
    case signedOut
    case signedIn(email: String?, planType: String?, accountType: String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var displayEmail: String? {
        if case .signedIn(let email, _, _) = self { return email }
        return nil
    }

    var displayPlan: String? {
        if case .signedIn(_, let plan, _) = self { return plan }
        return nil
    }
}
