import SwiftUI

/// First launch: hero, name and pets, then where the plants live (place, climate, home, rooms).
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
            } else if step == 2 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Where do your plants live?").font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text("Your climate, your home and this week's weather all change how much water and food they need. Tell me a little and I'll do the maths.")
                            .foregroundStyle(Jungle.subtle)
                        ClimateForm(compact: true)
                        RoomLightForm()
                    }
                }
                .scrollIndicators(.hidden)
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
            Button(step == 0 ? "Get started" : step == 1 ? "Next" : "Start my jungle" as LocalizedStringKey) {
                if step < 2 { withAnimation(.snappy) { step += 1 } } else { finish() }
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(24)
        .jungleBackdrop()
    }

    private func feature(_ s: String, _ t: LocalizedStringKey) -> some View {
        HStack(spacing: 14) { Image(systemName: s).font(.system(.title2, design: .rounded)).foregroundStyle(Jungle.leaf).frame(width: 36); Text(t).foregroundStyle(Jungle.text) }
    }

    private func finish() {
        Task { await CareReminders.requestPermission() }
        let s = JungleSettings.shared
        s.ownerName = name.trimmingCharacters(in: .whitespaces)
        s.hasCats = cats; s.hasDogs = dogs; s.hasKids = kids
        onDone()
    }
}
