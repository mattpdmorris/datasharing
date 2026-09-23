import Foundation

/// Public Investment Programme projects from Budget Volume 3, as compacted by
/// tools/build_app_data.py. Optional: the Projects tab only appears when the
/// file is bundled.
struct PIPFact: Identifiable, Hashable {
    let edition: Int
    /// 0 marks the five-year total exactly as the volume prints it.
    let refYear: Int
    let value: Double
    let printedPage: Int
    let pdfPage: Int
    let volumeIndex: Int

    var id: String { "\(edition)-\(refYear)-\(pdfPage)" }
    var isPrintedTotal: Bool { refYear == 0 }
}

struct PIPProject: Identifiable, Hashable {
    let pipNumber: String
    let name: String
    let agencyCode: String
    let agency: String
    let group: String
    /// Other names the same PIP number has been printed under.
    let otherNames: [String]
    let facts: [PIPFact]

    var id: String { pipNumber }

    var editions: [Int] { Array(Set(facts.map(\.edition))).sorted() }
    var latestEdition: Int? { facts.map(\.edition).max() }

    /// The year-by-year profile a given edition printed (excluding its total line).
    func profile(edition: Int) -> [PIPFact] {
        facts.filter { $0.edition == edition && !$0.isPrintedTotal }.sorted { $0.refYear < $1.refYear }
    }

    /// The five-year total as printed; falls back to the sum of the profile.
    func total(edition: Int) -> Double? {
        if let t = facts.first(where: { $0.edition == edition && $0.isPrintedTotal }) { return t.value }
        let p = profile(edition: edition)
        return p.isEmpty ? nil : p.reduce(0) { $0 + $1.value }
    }

    /// Amount the latest edition allocates to its own budget year.
    var currentYearAllocation: Double? {
        guard let e = latestEdition else { return nil }
        return facts.first { $0.edition == e && $0.refYear == e }?.value
    }

    var latestTotal: Double? { latestEdition.flatMap { total(edition: $0) } }

    static func == (l: PIPProject, r: PIPProject) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct PIPData: Sendable {
    let volumes: [String]
    let projects: [PIPProject]

    private struct Raw: Decodable {
        struct Project: Decodable {
            let pip: String
            let name: String
            let agency_code: String
            let agency: String
            let group: String
            let names: [String]?
        }
        let volumes: [String]
        let projects: [Project]
        let facts: [[Double]]
    }

    static func decode(_ data: Data) throws -> PIPData {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        var byProject: [Int: [PIPFact]] = [:]
        for f in raw.facts where f.count >= 7 {
            byProject[Int(f[0]), default: []].append(
                PIPFact(edition: Int(f[1]), refYear: Int(f[2]), value: f[3],
                        printedPage: Int(f[4]), pdfPage: Int(f[5]), volumeIndex: Int(f[6])))
        }
        let projects = raw.projects.enumerated().map { i, p in
            PIPProject(pipNumber: p.pip, name: p.name, agencyCode: p.agency_code, agency: p.agency,
                       group: p.group, otherNames: p.names ?? [], facts: byProject[i] ?? [])
        }
        return PIPData(volumes: raw.volumes, projects: projects)
    }
}
