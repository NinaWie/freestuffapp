//
//  AnonymousUser.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 20.12.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import Foundation
import Security

enum AnonymousUserID {
    // Keychain "account" key. Keep stable across versions.
    private static let keychainAccount = "anonUserId"
    // Use your bundle id as service to avoid collisions with other apps.
    private static var keychainService: String {
        Bundle.main.bundleIdentifier ?? "com.yourcompany.yourapp"
    }

    /// Returns a stable anonymous user id. Creates and stores it in Keychain on first run.
    static func getOrCreate() throws -> String {
        if let existing = try read() {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        try save(newId)
        return newId
    }

    /// Optional: call this if you ever want to reset the anonymous identity (usually not needed).
    static func reset() throws {
        try delete()
    }

    // MARK: - Keychain operations

    private static func read() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Accessibility: after first unlock is a good default for an app-level identifier.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.osStatus(status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return value
    }

    private static func save(_ value: String) throws {
        let data = Data(value.utf8)

        // Try add first
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        if addStatus != errSecDuplicateItem {
            throw KeychainError.osStatus(addStatus)
        }

        // If it already exists, update
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.osStatus(updateStatus)
        }
    }

    private static func delete() throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.osStatus(status)
    }
}

enum KeychainError: Error, CustomStringConvertible {
    case osStatus(OSStatus)
    case unexpectedData

    var description: String {
        switch self {
        case .osStatus(let status):
            return "Keychain OSStatus error: \(status)"
        case .unexpectedData:
            return "Keychain returned unexpected data"
        }
    }
}
