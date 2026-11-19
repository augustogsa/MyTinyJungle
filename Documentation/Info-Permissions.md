# Info.plist keys for My Tiny Jungle (merge into the app target)

| Key | Value |
|---|---|
| NSCameraUsageDescription | My Tiny Jungle uses the camera to scan plant products and take photos of your plants. |
| NSPhotoLibraryUsageDescription | Choose photos of your plants from your library. They stay on your device. |
| NSPhotoLibraryAddUsageDescription | Save plant photos you take in My Tiny Jungle to your library. |
| NSCalendarsWriteOnlyAccessUsageDescription | Add your plants' care reminders to your calendar. |
| NSCalendarsUsageDescription (iOS < 17 fallback) | Add your plants' care reminders to your calendar. |
| NSLocationWhenInUseUsageDescription | Your location tells My Tiny Jungle your hemisphere and season and lets it warn you about frost and heat for your plants. |
| ITSAppUsesNonExemptEncryption | NO (standard encryption only; answers export compliance for every build) |

Notifications: no Info.plist key; ask with `UNUserNotificationCenter.requestAuthorization` after explaining "Your plants will message you when they need water, light or care." Remote push needs entitlement `aps-environment`.

Contacts: use `CNContactPickerViewController` (ContactsUI) to pick a plant-sitter. No permission and no `NSContactsUsageDescription` needed. Only add that key if full Contacts access is ever used: "Pick a friend to share your plant-care link with."

Calendar: use `EKEventStore.requestWriteOnlyAccessToEvents()` (iOS 17+) so only the write-only key is shown.

## Entitlements (match the portal App ID)
- `aps-environment`
- `com.apple.developer.applesignin` = [Default]
- `com.apple.security.application-groups` = [group.com.simpleappscompany.mytinyjungle]
- `com.apple.developer.icloud-container-identifiers` = [iCloud.com.simpleappscompany.mytinyjungle], `com.apple.developer.icloud-services` = [CloudKit]
- `com.apple.developer.weatherkit`
- In-App Purchase: capability only, no entitlement key.

## pt-PT strings
- Camera: O My Tiny Jungle usa a câmara para ler produtos para plantas e fotografar as suas plantas.
- Photos: Escolha fotos das suas plantas na sua fototeca. Ficam no seu dispositivo.
- Photos add: Guarde na fototeca as fotos de plantas que tirar no My Tiny Jungle.
- Calendar: Adicione ao calendário os lembretes de cuidados das suas plantas.
- Location: A sua localização indica ao My Tiny Jungle o hemisfério e a estação, e permite avisá-lo de geadas e calor para as suas plantas.
