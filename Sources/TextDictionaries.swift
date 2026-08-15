import Foundation

struct DictionaryEntry: Codable, Equatable, Hashable {
    let from: String
    let to: String
}

enum TextDictionaries {
    static var system: [DictionaryEntry] {
        if let mainURL = Bundle.main.url(forResource: "system_dictionary", withExtension: "json") {
            if let data = try? Data(contentsOf: mainURL),
               let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
                return entries
            }
        }

        #if SWIFT_PACKAGE
            if let moduleURL = Bundle.module.url(forResource: "system_dictionary", withExtension: "json") {
                if let data = try? Data(contentsOf: moduleURL),
                   let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
                    return entries
                }
            }
        #endif

        return []
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
            let isHan = entry.from.range(of: "\\p{Han}", options: .regularExpression) != nil
            let escaped = NSRegularExpression.escapedPattern(for: entry.from)
            let pattern = isHan
                ? escaped
                : "(?<=^|\\s|[\\p{P}\\p{S}\\p{Han}])" + escaped + "(?=$|\\s|[\\p{P}\\p{S}\\p{Han}])"
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
