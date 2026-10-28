import Foundation
import Testing
@testable import Carli

struct NotesTests {
    private func snapshot() throws -> NotesSnapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotesSnapshot.self, from: Data("""
        {"folders":[{"id":"f1","name":"Casa","position":0},{"id":"f2","parent_id":"f1","name":"Cocina","position":0}],
         "notes":[{"id":"n1","type":"shopping","is_primary":true,"updated_at":"2026-10-27T10:00:00.000000Z",
                   "items":[{"id":"i1","note_id":"n1","text":"Leche","section_id":"s1","position":0},
                            {"id":"i2","note_id":"n1","text":"Pilas","position":1}]},
                  {"id":"n2","type":"text","folder_id":"f2","title":"Receta","updated_at":"2026-10-26T10:00:00.000000Z","items":[]}],
         "sections":[{"id":"s1","name":"Lácteos y huevos","position":0}],"products":[]}
        """.utf8))
    }

    @Test func foldersFormATree() throws {
        let s = try snapshot()
        #expect(s.children(of: nil).map(\.id) == ["f1"])
        #expect(s.folderPath(of: s.note("n2")!) == ["Casa", "Cocina"])
        #expect(s.recursiveCount("f1") == 1)
    }

    @Test func checkingAnItemAppliesLocally() throws {
        var s = try snapshot()
        let operation = NoteOperation(type: "item.upsert", payload: ["id": .string("i1"), "checked": .bool(true)])
        NotesStore.apply(operation, to: &s)
        #expect(s.note("n1")?.items.first?.checked == true)
        #expect(s.note("n1")?.openCount == 1)
    }

    @Test func shoppingGroupsFollowSections() throws {
        let s = try snapshot()
        let groups = ShoppingListView.groups(s.note("n1")!, s.sections)
        #expect(groups.map(\.title) == ["Lácteos y huevos", "Sin sección"])
    }

    @Test func guessesSectionByKeyword() throws {
        let s = try snapshot()
        #expect(SectionGuess.sectionId(for: "Huevos camperos", in: s.sections) == "s1")
        #expect(SectionGuess.sectionId(for: "Destornillador", in: s.sections) == nil)
    }

    @Test func searchIgnoresAccents() throws {
        let s = try snapshot()
        #expect(s.search("receta", filter: nil).map(\.id) == ["n2"])
        #expect(s.search("", filter: .shopping).map(\.id) == ["n1"])
    }
}
