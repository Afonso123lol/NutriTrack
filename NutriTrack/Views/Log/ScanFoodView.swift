import SwiftUI
import CoreData

struct ScanFoodView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let eatenAt: Date
    let onDescribe: () -> Void
    let onFinish: () -> Void

    private enum Phase {
        case scanning
        case loading(String)
        case product(Product)
        case notFound(String)
        case failed(String, String)
        case logged(FoodEntry, String)
    }

    @State private var phase: Phase = .scanning
    @State private var typedCode = ""
    @State private var portion: ProductPortion?
    @State private var customGrams = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(theme.colors.background.ignoresSafeArea())
                .navigationTitle("Scan food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isTyping = false }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .scanning: scanning
        case .loading(let code): loading(code)
        case .product(let product): productView(product)
        case .notFound(let code): notFound(code)
        case .failed(let code, let message): failed(code, message)
        case .logged(let entry, let text): logged(entry, text)
        }
    }

    private var scanning: some View {
        VStack(spacing: 16) {
            if BarcodeScanner.isAvailable {
                BarcodeScanner { code in lookUp(code) }
                    .clipShape(RoundedRectangle(cornerRadius: theme.shape.cardRadius, style: .continuous))
                    .frame(maxHeight: 360)
                    .accessibilityLabel("Barcode camera")
                Text("Point the camera at the barcode.")
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
            } else {
                Text("The camera scanner is not available on this device. Type the barcode instead.")
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                TextField("Type the barcode", text: $typedCode)
                    .keyboardType(.numberPad)
                    .font(theme.body(.body))
                    .foregroundStyle(theme.colors.textPrimary)
                    .padding(12)
                    .background(theme.colors.surface,
                                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
                    .focused($isTyping)
                Button("Find") { lookUp(typedCode) }
                    .buttonStyle(.themedCompact)
                    .disabled(!OpenFoodFacts.isValidBarcode(typedCode.filter(\.isNumber)))
            }
        }
        .padding()
    }

    private func loading(_ code: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Looking up \(code)…")
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(.top, 60)
    }

    private func productView(_ product: Product) -> some View {
        let info = product.info
        let choices = ProductPortion.choices(for: info, lastGrams: product.lastGrams > 0 ? product.lastGrams : nil)
        let chosen = selectedPortion(default: choices.first)
        let preview = chosen.map { info.analysis(grams: $0.grams) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.name)
                        .font(theme.display(.title3))
                        .foregroundStyle(theme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let brand = info.brand {
                        Text(brand)
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Text(product.source == "openfoodfacts" ? "Label values · Open Food Facts" : "Label values · your photo")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textMuted)
                }

                Text("Per 100 g: \(Int(info.caloriesPer100.rounded())) kcal · P \(grams(info.proteinPer100)) · C \(grams(info.carbsPer100)) · F \(grams(info.fatPer100))")
                    .font(theme.body(.footnote))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How much?")
                        .font(theme.body(.headline))
                        .foregroundStyle(theme.colors.textPrimary)
                    ForEach(choices) { choice in
                        portionButton(choice, isSelected: chosen == choice && customGrams.isEmpty)
                    }
                    HStack {
                        TextField("Other amount", text: $customGrams)
                            .keyboardType(.decimalPad)
                            .font(theme.body(.body))
                            .foregroundStyle(theme.colors.textPrimary)
                            .focused($isTyping)
                        Text("g")
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .padding(12)
                    .background(theme.colors.surface,
                                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
                }

                if let preview {
                    Text("\(Int(preview.calories.rounded())) kcal · \(Int(preview.proteinG.rounded())) g protein")
                        .font(theme.body(.title3).weight(.semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                }

                Button("Add") {
                    guard let chosen else { return }
                    isTyping = false
                    let entry = FoodEntry.create(from: product, portion: chosen, timestamp: eatenAt, in: ctx)
                    let text = "\(chosen.label) · \(Int(entry.calories.rounded())) kcal"
                    withAnimation { phase = .logged(entry, text) }
                }
                .buttonStyle(.themedPrimary)
                .disabled(chosen == nil)

                attribution(product)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func portionButton(_ choice: ProductPortion, isSelected: Bool) -> some View {
        Button {
            customGrams = ""
            portion = choice
        } label: {
            HStack {
                Text(choice.label)
                    .font(theme.body(.body))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(isSelected ? theme.colors.surfaceElevated : theme.colors.surface,
                        in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
        }
        .buttonStyle(.pressScale)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func attribution(_ product: Product) -> some View {
        Group {
            if product.source == "openfoodfacts", let ean = product.ean, let url = OpenFoodFacts.pageURL(ean: ean) {
                Link(OpenFoodFacts.attribution, destination: url)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textMuted)
            }
        }
    }

    private func notFound(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Not in Open Food Facts yet")
                .font(theme.display(.title3))
                .foregroundStyle(theme.colors.textPrimary)
            Text("Barcode \(code). Describe the product instead, with the brand and the amount, or try another barcode.")
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Describe it instead") {
                dismiss()
                onDescribe()
            }
            .buttonStyle(.themedPrimary)
            Button("Scan another") { restart() }
                .buttonStyle(.themedOutline)
        }
        .padding()
    }

    private func failed(_ code: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(message)
                .font(theme.body(.body))
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { lookUp(code) }
                .buttonStyle(.themedPrimary)
            Button("Scan another") { restart() }
                .buttonStyle(.themedOutline)
        }
        .padding()
    }

    private func logged(_ entry: FoodEntry, _ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(theme.colors.success)
                .accessibilityHidden(true)
            Text("Logged")
                .font(theme.display(.title3))
                .foregroundStyle(theme.colors.textPrimary)
            Text(text)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
            Button("Done") {
                dismiss()
                onFinish()
            }
            .buttonStyle(.themedPrimary)
            Button("Undo") {
                entry.remove(from: ctx)
                restart()
            }
            .buttonStyle(.themedOutline)
            Button("Scan another") { restart() }
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.accent)
        }
        .padding()
        .padding(.top, 30)
    }

    private func selectedPortion(default fallback: ProductPortion?) -> ProductPortion? {
        if let grams = Double(customGrams.replacingOccurrences(of: ",", with: ".")), grams > 0, grams < 5000 {
            return ProductPortion(label: "\(ProductPortion.grams(grams)) g", grams: grams)
        }
        return portion ?? fallback
    }

    private func grams(_ value: Double) -> String {
        "\(ProductPortion.grams((value * 10).rounded() / 10)) g"
    }

    private func restart() {
        portion = nil
        customGrams = ""
        typedCode = ""
        withAnimation { phase = .scanning }
    }

    private func lookUp(_ raw: String) {
        let code = raw.filter(\.isNumber)
        guard OpenFoodFacts.isValidBarcode(code) else { return }
        isTyping = false
        portion = nil
        customGrams = ""
        if let cached = Product.find(ean: code, in: ctx) {
            phase = .product(cached)
            return
        }
        phase = .loading(code)
        Task {
            switch await OpenFoodFactsClient.lookup(ean: code) {
            case .found(let info):
                phase = .product(Product.store(info, source: "openfoodfacts", in: ctx))
            case .notFound:
                phase = .notFound(code)
            case .failed(let message):
                phase = .failed(code, message)
            }
        }
    }
}
