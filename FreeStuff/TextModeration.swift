//
//  TextModeration.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 21.12.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import Foundation

enum TextModeration {

    /// Return a human-friendly reason if the post should be blocked/held; otherwise nil.
    static func blockReason(title: String, description: String) -> String? {
        let combined = "\(title)\n\(description)"

        // PII / doxxing checks first (high signal)
        if containsEmail(combined) {
            return "Please remove email addresses from your post."
        }
        if containsPhoneNumber(combined) {
            return "Please remove phone numbers from your post."
        }

        // Objectionable content checks
        if containsBannedTerm(combined) {
            return "Your post contains language that isn’t allowed. Please remove it and try again."
        }

        if containsThreateningLanguage(combined) {
            return "Your post appears to contain threatening language. Please edit and try again."
        }

        return nil
    }

    // MARK: - Banned term filtering (profanity/slurs/explicit sexual terms)

    private static let bannedTerms: Set<String> = [
        // PROFANITY
        "fuck", "bitch", "asshole",
        // EXPLICIT SEXUAL TERMS
        "porn", "nude",
    ]

    private static func containsBannedTerm(_ text: String) -> Bool {
        // Normalize and tokenize to catch simple punctuation variations.
        let tokens = tokenize(normalize(text))
        for t in tokens {
            if bannedTerms.contains(t) { return true }
        }

        // Optional: catch obvious obfuscations like f.u.c.k or f*ck by stripping non-alphanumerics.
        // This increases false-positive risk, so keep it conservative.
        let squashed = squashToAlnum(normalize(text))
        for term in bannedTerms {
            if squashed.contains(term) { return true }
        }

        return false
    }

    // MARK: - Threat language (lightweight heuristics)

    private static let threatPhrases: [String] = [
        "kill you", "i will kill", "hurt you", "i will hurt",
        "shoot you", "i will shoot", "stab you", "i will stab",
        "bomb", "i will find you"
    ]

    private static func containsThreateningLanguage(_ text: String) -> Bool {
        let n = normalize(text)
        return threatPhrases.contains(where: { n.contains($0) })
    }

    // MARK: - Doxxing / PII patterns

    private static func containsEmail(_ text: String) -> Bool {
        // A practical email regex (not perfect, good enough for filtering).
        let pattern = #"(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}"#
        return matches(pattern: pattern, in: text)
    }

    private static func containsPhoneNumber(_ text: String) -> Bool {
        // Broad phone pattern: supports +country, spaces, hyphens, parentheses.
        // You will get some false positives; tune to your market if needed.
        let pattern = #"(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{2,4}\)?[\s-]?)?\d{3}[\s-]?\d{2}[\s-]?\d{2,4}"#
        // Require at least ~7 digits overall to reduce false positives.
        let digits = text.filter(\.isNumber)
        if digits.count < 7 { return false }
        return matches(pattern: pattern, in: text)
    }

    private static func matches(pattern: String, in text: String) -> Bool {
        do {
            let re = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return re.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }

    // MARK: - Normalization helpers

    private static func normalize(_ text: String) -> String {
        // Lowercase, remove diacritics, and standardize whitespace.
        let lowered = text.lowercased()
        let folded = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded
    }

    private static func tokenize(_ text: String) -> [String] {
        // Split on non-alphanumeric. Keeps words and numbers.
        let parts = text.split { !$0.isLetter && !$0.isNumber }
        return parts.map { String($0) }.filter { !$0.isEmpty }
    }

    private static func squashToAlnum(_ text: String) -> String {
        // Remove everything except letters and digits, so "f.u.c.k" -> "fuck".
        return text.filter { $0.isLetter || $0.isNumber }
    }
}
