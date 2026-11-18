import SwiftUI

/// First launch: hero, name, pets, hemisphere from region.
struct OnboardingView: View {
    var onDone: () -> Void
    @State private var step = 1
    @State private var name = JungleSettings.shared.ownerName
    @State private var cats = false
    @State private var dogs = false
    @State private var kids = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if step == 0 {
                Image(systemName: "leaf.circle.fill").font(.system(size: 88)).foregroundStyle(Jungle.leaf)
                Text("My Tiny Jungle").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text("Your plants, talking to you.").foregroundStyle(Jungle.subtle)
                VStack(alignment: .leading, spacing: 14) {
                    feature("bubble.left.and.text.bubble.right", "Your plants tell you when they're thirsty or hungry")
                    feature("camera.viewfinder", "Snap a photo to meet your plant and help it feel better")
                    feature("barcode.viewfinder", "Find the soil and food each plant will love")
                }
                .padding(.top, 10)
            } else {
                Text("A little about you").font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                TextField("Your name", text: $name).textFieldStyle(.roundedBorder).textContentType(.givenName)
                VStack(spacing: 0) {
                    Toggle("Cats at home", isOn: $cats).padding(12)
                    Toggle("Dogs at home", isOn: $dogs).padding(12)
                    Toggle("Small children", isOn: $kids).padding(12)
                }
                .jungleCard()
                Text("We'll gently warn you about any plant that could hurt them.").font(.footnote).foregroundStyle(Jungle.subtle)
            }
            Spacer()
            Button(step == 0 ? "Get started" : "Start my jungle") {
                if step == 0 { withAnimation(.snappy) { step = 1 } } else { finish() }
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(24)
        .jungleBackdrop()
    }

    private func feature(_ s: String, _ t: String) -> some View {
        HStack(spacing: 14) { Image(systemName: s).font(.system(.title2, design: .rounded)).foregroundStyle(Jungle.leaf).frame(width: 36); Text(t).foregroundStyle(Jungle.text) }
    }

    private func finish() {
        Task { await CareReminders.requestPermission() }
        let s = JungleSettings.shared
        s.ownerName = name.trimmingCharacters(in: .whitespaces)
        s.hasCats = cats; s.hasDogs = dogs; s.hasKids = kids
        let south: Set<String> = ["AU", "NZ", "BR", "AR", "CL", "ZA", "UY", "PY", "PE", "BO"]
        s.southernHemisphere = south.contains(Locale.current.region?.identifier ?? "")
        onDone()
    }
}
