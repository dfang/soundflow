import Foundation

struct DictionaryEntry: Codable, Equatable, Hashable {
    let from: String
    let to: String
}

enum TextDictionaries {
    static var system: [DictionaryEntry] {
        guard let url = Bundle.main.url(forResource: "system_dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func loadUserDictionary() -> [DictionaryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "userDictionary"),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func saveUserDictionary(_ entries: [DictionaryEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "userDictionary")
        }
    }

    static func applyDictionaries(
        to text: String,
        system: [DictionaryEntry] = TextDictionaries.system,
        user: [DictionaryEntry] = TextDictionaries.loadUserDictionary()
    ) -> String {
        var result = text
        let allEntries = system + user

        for entry in allEntries {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.from) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: entry.to
                )
            }
        }

        return result
    }
}
