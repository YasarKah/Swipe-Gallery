//
//  DateFormatterHelper.swift
//  Swipe Gallery
//
//  Türkçe ay kısaltmaları ve "OCA '25" formatı için yardımcı.
//

import Foundation

enum DateFormatterHelper {
    /// Türkçe ay kısaltmaları: OCA, ŞUB, MAR, ...
    private static let monthAbbreviationsTR = [
        "OCA", "ŞUB", "MAR", "NİS", "MAY", "HAZ",
        "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA"
    ]

    private static let monthAbbreviationsEN = [
        "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
    ]

    /// Ay numarası (1–12) için Türkçe kısaltma
    static func monthAbbreviation(month: Int, language: AppLanguage = .turkish) -> String {
        guard (1...12).contains(month) else { return "" }
        switch language {
        case .turkish:
            return monthAbbreviationsTR[month - 1]
        case .english:
            return monthAbbreviationsEN[month - 1]
        }
    }

    /// "OCA '25" formatında string (ay + yılın son 2 hanesi)
    static func monthYearShort(month: Int, year: Int, language: AppLanguage = .turkish) -> String {
        let abbr = monthAbbreviation(month: month, language: language)
        let yearShort = year % 100
        return "\(abbr) '\(String(format: "%02d", yearShort))"
    }

    /// Verilen tarihin ay/yıl bilgisiyle "OCA '25" formatı
    static func monthYearShort(from date: Date, calendar: Calendar = .current, language: AppLanguage = .turkish) -> String {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return monthYearShort(month: month, year: year, language: language)
    }

    static func smartClusterTitle(from date: Date, language: AppLanguage = .turkish) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .turkish ? "d MMM • HH:mm" : "MMM d • HH:mm"
        return formatter.string(from: date)
    }
}
