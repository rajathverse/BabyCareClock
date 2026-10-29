import SwiftUI
import Vision
import VisionKit

/// A vaccine read from a photo of the vaccination card, checked by the parent before it's saved.
struct ScannedVaccine: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var date: Date
    var isGiven: Bool
}

/// Reads vaccine names and dates from photos of a vaccination card, on the iPhone.
/// Cards differ a lot, so the result is only a starting point for the parent to check.
enum VaccineCardReader {
    private struct Piece {
        let text: String
        /// Normalised, origin at the bottom left.
        let box: CGRect
    }

    static func read(_ images: [UIImage], now: Date = Date()) async -> [ScannedVaccine] {
        await Task.detached(priority: .userInitiated) {
            var found: [ScannedVaccine] = []
            for image in images {
                for vaccine in vaccines(in: recognize(image), now: now)
                where !found.contains(where: { $0.name == vaccine.name && Calendar.current.isDate($0.date, inSameDayAs: vaccine.date) }) {
                    found.append(vaccine)
                }
            }
            return found.sorted { $0.date < $1.date }
        }.value
    }

    private static func recognize(_ image: UIImage) -> [Piece] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation).perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { Piece(text: $0.string, box: observation.boundingBox) }
        }
    }

    /// Each piece that names a vaccine, paired with a date on the same line of the card.
    private static func vaccines(in pieces: [Piece], now: Date) -> [ScannedVaccine] {
        pieces.compactMap { piece in
            guard namesVaccine(piece.text) else { return nil }
            let row = pieces.filter { abs($0.box.midY - piece.box.midY) < max(piece.box.height, 0.01) * 0.75 && $0.box.minX >= piece.box.minX - 0.01 }
            let dates = row.flatMap { self.dates(in: $0.text) }
            guard !dates.isEmpty else { return nil }
            let name = cleanedName(piece.text)
            guard !name.isEmpty else { return nil }
            // Only a line with a due date and a later given date counts as given. With a single
            // date it stays not given, so a missed vaccine is never hidden; the parent can tick it.
            if dates.count >= 2, let given = dates.filter({ $0 <= now }).max(), given > dates.min()! || dates.filter({ $0 <= now }).count >= 2 {
                return ScannedVaccine(name: name, date: given, isGiven: true)
            }
            return ScannedVaccine(name: name, date: dates.min()!, isGiven: false)
        }
    }

    private static let acronyms = try! NSRegularExpression(pattern: #"\b(BCG|f?IPV|OPV|Hep[\s-]?[AB]|HEP[\s-]?[AB]|DT[wa]?P|DTP|DPT|Hib|HIB|PCV|MMR|MR|TCV|JE|Tdap|Td|RV|HPV)\b"#)
    private static let words = try! NSRegularExpression(pattern: #"(hepatitis|rota|pneumo|measles|typhoid|varicella|chicken\s*pox|influenza|penta|hexa|polio|diphtheria)"#, options: .caseInsensitive)
    private static let datePattern = try! NSRegularExpression(pattern: #"\b(\d{1,2})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{2,4})\b"#)

    private static func namesVaccine(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return acronyms.firstMatch(in: text, range: range) != nil || words.firstMatch(in: text, range: range) != nil
    }

    /// Indian cards write dates day first: 12/01/2026, 12-1-26, 12.01.26.
    private static func dates(in text: String) -> [Date] {
        datePattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            let parts = (1...3).compactMap { Range(match.range(at: $0), in: text).flatMap { Int(text[$0]) } }
            guard parts.count == 3 else { return nil }
            let year = parts[2] < 100 ? 2000 + parts[2] : parts[2]
            guard (1...31).contains(parts[0]), (1...12).contains(parts[1]), (2010...2045).contains(year) else { return nil }
            return Calendar.current.date(from: DateComponents(year: year, month: parts[1], day: parts[0]))
        }
    }

    private static func cleanedName(_ text: String) -> String {
        let withoutDates = datePattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        let trimmed = withoutDates
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // "OPV-O" is almost always "OPV-0" read wrongly.
        let fixed = trimmed.replacingOccurrences(of: #"([-\s])[Oo]\b"#, with: "$10", options: .regularExpression)
        return String(fixed.prefix(40))
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// The system document camera, which finds the card's edges and straightens the photo.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner

        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}

/// What was read from the card, to fix or remove before saving.
struct ScanReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var vaccines: [ScannedVaccine]
    let onSave: ([ScannedVaccine]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($vaccines) { $vaccine in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Vaccine name", text: $vaccine.name)
                                .font(.headline)
                            DatePicker("Date", selection: $vaccine.date, displayedComponents: .date)
                            Toggle("Given", isOn: $vaccine.isGiven)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { vaccines.remove(atOffsets: $0) }
                } footer: {
                    Text("Read from your card. Fix any names or dates, and remove anything that's wrong.")
                }
            }
            .softFormBackground()
            .navigationTitle("Check the vaccines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(vaccines.count) vaccines") {
                        onSave(vaccines.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty })
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(vaccines.isEmpty)
                }
            }
        }
    }
}
