//
//  NotificationNames.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 21/08/2025.
//

import Foundation

extension Notification.Name {
    // Posted after a successful authenticate() that set a fresh session.
    static let ivyDidAuthenticate = Notification.Name("IvyDidAuthenticate")
    // Posted when logout() clears the in-memory session.
    static let ivyDidLogout       = Notification.Name("IvyDidLogout")
}
