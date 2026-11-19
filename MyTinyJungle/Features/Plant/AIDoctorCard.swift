import SwiftUI

/// Plus: a second opinion from the AI plant doctor (api.mytinyjungle.com/v1/diagnose). The photo is sent
/// once for the answer and never stored.
struct AIDoctorCard: View {
    let photo: Data
    let plant: Plant
    @State private var answer: AIDiagnosis?
    @State private var working = false
    @State private var failed: String?
    @State private var paywall = false
    @State private var helped: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let a = answer {
                HStack(spacing: 8) {
                    Icon3DView(.healthShield, size: 28)
                    Text(a.problem).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Spacer(minLength: 0)
                    if a.urgent { Text(Grammar.pt(String(localized: "Act soon", comment: "AI doctor urgency badge; max 12 chars"))).font(.caption.weight(.bold)).foregroundStyle(Jungle.warmText).padding(.horizontal, 8).padding(.vertical, 3).background(Jungle.warmFill, in: Capsule()) }
                }
                Text(a.why).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                if let c = a.context, !c.isEmpty {
                    Text(c).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(a.steps.enumerated()), id: \.offset) { i, s in
                    Label { Text(s).font(.subheadline) } icon: { Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(Jungle.accentText) }
                }
                if let ref = a.ref, !ref.isEmpty { feedback(ref) }
            } else if working {
                ErtyLoading(text: Grammar.pt(String(localized: "Asking the plant doctor…", comment: "AI doctor loading text")))
            } else {
                Button { ask() } label: {
                    HStack {
                        Icon3DView(.healthShield, size: 24)
                        Text(Grammar.pt(String(localized: "Ask the AI plant doctor", comment: "Health check button: AI second opinion (Plus); max 30 chars"))).font(.headline)
                        Spacer(minLength: 0)
                        if !Store.shared.isPlus { Text("Plus").font(.caption.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Jungle.mint, in: Capsule()) }
                    }
                    .foregroundStyle(Jungle.text).padding(14)
                    .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
                }.buttonStyle(.plain)
                if let failed { Text(failed).font(.caption).foregroundStyle(Jungle.subtle) }
            }
        }
        .sheet(isPresented: $paywall) { PaywallView() }
    }

    @ViewBuilder private func feedback(_ ref: String) -> some View {
        if let helped {
            Text(helped ? Grammar.pt(String(localized: "Glad it helped!", comment: "AI doctor: thanks after 'Yes' feedback"))
                        : Grammar.pt(String(localized: "Thanks, that helps us improve.", comment: "AI doctor: thanks after 'No' feedback")))
                .font(.caption).foregroundStyle(Jungle.subtle)
        } else {
            HStack(spacing: 10) {
                Text(Grammar.pt(String(localized: "Did this help?", comment: "AI doctor: feedback question; max 20 chars"))).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Spacer(minLength: 0)
                ForEach([true, false], id: \.self) { yes in
                    Button {
                        helped = yes
                        Task { await Brain.feedback(ref: ref, helped: yes) }
                    } label: {
                        Text(yes ? Grammar.pt(String(localized: "Yes", comment: "AI doctor feedback button; short")) : Grammar.pt(String(localized: "No", comment: "AI doctor feedback button; short")))
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered).tint(Jungle.tint)
                }
            }
            .padding(.top, 4)
        }
    }

    private func ask() {
        guard Store.shared.isPlus else { paywall = true; return }
        guard JungleAPI.shared.hasSession else { failed = Grammar.pt(String(localized: "Sign in to use the AI plant doctor.", comment: "AI doctor: needs account")); return }
        working = true; failed = nil
        let jpeg = ImageShrinker.jpeg(photo, maxSide: 1280)
        let species = plant.species?.scientific ?? ""
        Task {
            defer { working = false }
            do {
                answer = try await AIDiagnosis.ask(photo: jpeg, species: species, note: plant.name, plant: plant)
                Analytics.track("ai_doctor")
            } catch where ServerNotice.message(for: error) != nil {
                failed = ServerNotice.message(for: error)
            } catch {
                failed = Grammar.pt(String(localized: "The plant doctor is unavailable right now. Try again later.", comment: "AI doctor: generic failure"))
            }
        }
    }
}

nonisolated struct AIDiagnosis: Decodable {
    var problem: String
    var confidence: String
    var why: String
    var steps: [String]
    var urgent: Bool
    var source: String?
    var context: String?
    var ref: String?

    @MainActor static func ask(photo: Data, species: String, note: String, plant: Plant?) async throws -> AIDiagnosis {
        nonisolated struct B: Encodable { let photo, species, note, lang: String; let situation: [String: [String]]?; let lat, lon: Double? }
        let sit = PlantSituation.build(plant)
        let at = PlantSituation.coords
        let body = B(photo: photo.base64EncodedString(), species: species, note: note, lang: PlantSituation.lang,
                     situation: sit.isEmpty ? nil : sit, lat: at?.lat, lon: at?.lon)
        return try await JungleAPI.shared.send("POST", "/v1/diagnose", body: body)
    }
}
