import AppKit
import FleetMacOS
import SwiftUI
import Testing
import ViewInspector

// Synthetic fixture: a multiline practice answer per project. No downstream application is modeled.

@MainActor
final class PracticeModel: ObservableObject {
    @Published var projectName = "Alpha"
    @Published var saved: [String] = []
}

struct PracticeForm: View {
    @ObservedObject var model: PracticeModel
    let seam: InspectionSeam<PracticeForm>
    @State private var answer = ""
    var lockedEditor = false
    var duplicateEditor = false

    var body: some View {
        VStack {
            Text(model.projectName)
            TextEditor(text: $answer)
                .accessibilityIdentifier("practice.answer")
                .disabled(lockedEditor)
            if duplicateEditor {
                TextEditor(text: $answer).accessibilityIdentifier("practice.answer")
            }
            Button("Save answer") { model.saved.append(answer) }
            Button("Switch project") {
                model.projectName = model.projectName == "Alpha" ? "Beta" : "Alpha"
                answer = ""
            }
        }
        .frame(width: 320, height: 240)
        .onReceive(seam.notice) { seam.visit(self) }
    }
}

@MainActor
private func expectFailure(_ expected: MacOSQueryFailure, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(expected)") } catch let failure as MacOSQueryFailure {
        #expect(failure == expected)
    } catch { Issue.record("unexpected error \(error)") }
}

@MainActor
@Suite("Mounted macOS TextEditor interaction", .serialized)
struct MacOSTextEditorInteractionTests {
    @Test func editingTheBindingPreservesNewlinesSavesAndSwitchingClears() async throws {
        let model = PracticeModel()
        let seam = InspectionSeam<PracticeForm>()
        try await FleetMacOS.withHostedView(PracticeForm(model: model, seam: seam)) { host in
            try await host.waitUntilReady()
            #expect(!host.window.isKeyWindow)
            let multiline = "line one\n\nline three\n"
            try await host.inspect(seam) { screen in
                let editor = try screen.textEditor(identifier: "practice.answer")
                let value1 = try editor.text()
                #expect(value1 == "")
                let value2 = try editor.setText(multiline)
                #expect(value2 == .writesBinding)
                #expect(screen.trace == ["write binding of text editor 'practice.answer' (value withheld)"])
            }
            try await host.inspect(seam) { screen in
                let value3 = try screen.textEditor(identifier: "practice.answer").text()
                #expect(value3 == multiline)
            }
            try await host.inspect(seam) { try $0.button("Save answer").tap() }
            #expect(model.saved == [multiline])

            try await host.inspect(seam) { try $0.textEditor(identifier: "practice.answer").setText("") }
            try await host.inspect(seam) { try $0.button("Save answer").tap() }
            #expect(model.saved == [multiline, ""])

            try await host.inspect(seam) { try $0.textEditor(identifier: "practice.answer").setText("draft") }
            try await host.inspect(seam) { try $0.button("Switch project").tap() }
            try await host.waitForUpdate("project switched") { model.projectName == "Beta" }
            try await host.inspect(seam) { screen in
                let value4 = try screen.textEditor(identifier: "practice.answer").text()
                #expect(value4 == "")
            }
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func absentAmbiguousDisabledAndObsoleteStayDistinct() async throws {
        let seam = InspectionSeam<PracticeForm>()
        try await FleetMacOS.withHostedView(PracticeForm(model: PracticeModel(), seam: seam, duplicateEditor: true)) { host in
            try await host.waitUntilReady()
            try await host.inspect(seam) { screen in
                expectFailure(.ambiguous(target: "text editor 'practice.answer'", scope: "screen", count: 2)) {
                    _ = try screen.textEditor(identifier: "practice.answer")
                }
                expectFailure(.absent(target: "text editor 'missing'", scope: "screen")) { _ = try screen.textEditor(identifier: "missing") }
            }
        }
        let lockedSeam = InspectionSeam<PracticeForm>()
        try await FleetMacOS.withHostedView(PracticeForm(model: PracticeModel(), seam: lockedSeam, lockedEditor: true)) { host in
            try await host.waitUntilReady()
            var retained: TextEditorHandle?
            try await host.inspect(lockedSeam) { screen in
                let editor = try screen.textEditor(identifier: "practice.answer")
                #expect(!editor.isEnabled)
                expectFailure(.disabled(target: "text editor 'practice.answer'", scope: "screen")) { try editor.setText("blocked") }
                let value5 = try editor.text()
                #expect(value5 == "")
                retained = editor
            }
            expectFailure(.obsolete(target: "text editor 'practice.answer'")) { _ = try retained?.text() }
            expectFailure(.obsolete(target: "text editor 'practice.answer'")) { try retained?.setText("late") }
        }
    }

    @Test func aHandleFromAnEarlierScreenCannotEditASuccessorScreen() async throws {
        let firstSeam = InspectionSeam<PracticeForm>()
        var retained: TextEditorHandle?
        try await FleetMacOS.withHostedView(PracticeForm(model: PracticeModel(), seam: firstSeam)) { host in
            try await host.waitUntilReady()
            try await host.inspect(firstSeam) { retained = try $0.textEditor(identifier: "practice.answer") }
        }
        let successorSeam = InspectionSeam<PracticeForm>()
        try await FleetMacOS.withHostedView(PracticeForm(model: PracticeModel(), seam: successorSeam)) { host in
            try await host.waitUntilReady()
            expectFailure(.obsolete(target: "text editor 'practice.answer'")) { try retained?.setText("STALE") }
            try await host.inspect(successorSeam) { screen in
                let value6 = try screen.textEditor(identifier: "practice.answer").text()
                #expect(value6 == "")
            }
        }
    }
}
