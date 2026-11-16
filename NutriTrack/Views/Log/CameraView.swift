import SwiftUI

struct CameraView: View {
    @Environment(\.theme) private var theme
    let profile: UserProfile
    @EnvironmentObject var pendingStore: PendingMealStore
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showPicker = false
    @State private var showLibrary = false
    @State private var note = ""
    @State private var isOnPlate = false
    @State private var isScanning = false
    @State private var eatenAt = Date()
    @FocusState private var isWritingNote: Bool

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var usualPlateDiameter: Double { profile.plateDiameterCm > 0 ? profile.plateDiameterCm : 26 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button {
                    isScanning = true
                } label: {
                    Label("Scan a barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.themedOutline)
                .padding(.horizontal)

                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
                        .padding(.horizontal)
                        .onTapGesture { showPicker = true }
                } else {
                    RoundedRectangle(cornerRadius: theme.shape.cardRadius, style: .continuous)
                        .fill(theme.colors.surface)
                        .frame(height: 200)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(theme.colors.accent)
                                Text("Tap to photograph your meal")
                                    .font(theme.body(.subheadline))
                                    .foregroundStyle(theme.colors.textSecondary)
                                Text("No photo? Describe the meal below.")
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textMuted)
                            }
                        }
                        .padding(.horizontal)
                        .onTapGesture { showPicker = true }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                }

                if capturedImage != nil {
                    Toggle(isOn: $isOnPlate) {
                        HStack {
                            Image(systemName: "circle.dashed")
                                .foregroundStyle(theme.colors.textSecondary)
                                .accessibilityHidden(true)
                            Text("On my usual plate (\(Int(usualPlateDiameter)) cm)")
                                .font(theme.body(.subheadline))
                                .foregroundStyle(theme.colors.textPrimary)
                        }
                    }
                    .padding(.horizontal)
                }

                DatePicker(selection: $eatenAt, in: ...Date()) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(theme.colors.textSecondary)
                        Text("Eaten at")
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                }
                .padding(.horizontal)

                TextField(capturedImage == nil ? "What you ate: 1 banana, 2 slices of bread, 200 g chicken..."
                                               : "Note (optional): cooking method, spices, portions...",
                          text: $note, axis: .vertical)
                    .font(theme.body(.body))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(3, reservesSpace: true)
                    .padding()
                    .background(theme.colors.surface,
                                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
                    .padding(.horizontal)
                    .focused($isWritingNote)
                    .submitLabel(.done)
                    .onChange(of: note) { _, newValue in
                        let result = MultilineField.handleReturn(in: newValue)
                        guard result.shouldClose else { return }
                        note = result.text
                        isWritingNote = false
                    }

                Spacer()

                Button("Analyse Meal") {
                    let diameter: Double? = capturedImage != nil && isOnPlate ? usualPlateDiameter : nil
                    pendingStore.submit(image: capturedImage, note: trimmedNote.isEmpty ? nil : trimmedNote,
                                        plateDiameter: diameter, eatenAt: eatenAt)
                    dismiss()
                }
                .buttonStyle(.themedPrimary)
                .disabled(capturedImage == nil && trimmedNote.isEmpty)
                .padding(.horizontal)
            }
            .padding(.top)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isScanning) {
                ScanFoodView(eatenAt: eatenAt,
                             onDescribe: { isWritingNote = true },
                             onFinish: { dismiss() })
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(image: $capturedImage, isPresented: $showPicker, sourceType: .camera)
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(image: $capturedImage, isPresented: $showLibrary, sourceType: .photoLibrary)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { isWritingNote = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isWritingNote = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button { showLibrary = true } label: { Image(systemName: "photo.on.rectangle") }
                            .accessibilityLabel("Choose from library")
                        Button { showPicker = true } label: { Image(systemName: "camera") }
                            .accessibilityLabel("Take photo")
                    }
                }
            }
        }
    }
}
