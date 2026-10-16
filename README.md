# NutriTrack

A personal nutrition and energy-optimization iOS app. Take a photo of your meal — an AI model identifies the components, estimates weights, and calculates 35+ nutrients with internal consistency validation. Track macros, micronutrients, water, weight, supplements, sleep, and daily energy, and get AI coaching that connects all of it.

Built with SwiftUI + CoreData. All data lives on the device; an optional sync can copy it to a small server you run yourself (`server/`). Photos are sent to the model only as a downscaled copy at capture time.

---

## Features

### 📸 AI Meal Analysis
- Snap a photo with the camera or pick one from the photo library
- Optional text note (e.g. "3 medium eggs, cooked in olive oil") and per-meal plate diameter (18–34 cm) used as a physical scale reference
- Powered by **Gemini 3.5 Flash Lite** (with Gemma 4 31B as fallback) via the Google AI Studio API, with a structured 3-step prompt: identify components → estimate weights → apply USDA FoodData Central reference values
- **Background analysis**: the capture sheet closes immediately; a shimmer card on the Home screen shows progress, then the result with Save / Discard
- Full **preview sheet** before saving: every nutrient, the AI's comment, and any validation adjustments
- Non-food detection: photos without food are rejected with a clear message
- Resilient networking: automatic retry on server errors (HTTP 500/503), 90 s timeout, images downscaled to ≤1024 px before upload
- Robust parsing: tolerates reasoning text and markdown around the model's JSON (extracts the last balanced JSON object)

### ✅ Nutrient Validation Engine
Every analysis passes through `NutrientValidator` before reaching the user:
- **4-4-9 rule**: calories must match protein×4 + carbs×4 + fat×9 within 5%, otherwise they are recalculated from the macros
- **Cross-field checks**: sugar ≤ carbs, fiber ≤ carbs, saturated fat ≤ total fat, fat subtypes scaled to never exceed total fat
- **Outlier clamps**: per-meal plausibility bounds for every micronutrient (e.g. sodium ≤ 8 g, selenium ≤ 2000 µg)
- **Missing-data flag**: an analysis with calories but zeroed micronutrients is flagged as unreliable instead of silently accepted
- All corrections are listed in an "Adjustments" section in the preview, so you always know what was touched

### 📊 Tracked Nutrients (35+)
- **Macros**: calories, protein, carbohydrates (+ net carbs, fiber, sugar), fat (+ saturated, monounsaturated, polyunsaturated, trans), omega-3
- **Minerals**: sodium, potassium, calcium, iron, zinc, magnesium, phosphorus, selenium, copper
- **Vitamins**: A, C, D, E, K, B1, B2, B3, B5, B6, B12, folate (B9)
- **Water**: quick +250 ml logging with daily reset

### 🏠 Home Dashboard
- Large calorie counter with gradient progress ring
- Macro rings (protein / carbs / fat) with icons and personalized targets
- Water row, pending-analysis cards, today's meals and supplements
- **Advanced Metrics**: expandable section with net carbs, sugar, fiber, full fat breakdown, omega-3, sodium and potassium
- Tap any meal for the complete nutritional breakdown; swipe to delete

### 🌙 Sleep & Energy Check-in
- **Sleep button**: tap the moon when you go to bed — no wearable needed
- **Morning check-in card**: hours slept pre-filled from the sleep button (sanity-checked to 3–14 h), energy 1–5, sleep quality 1–5 — a five-second ritual
- Data accumulates for energy/nutrition/sleep correlation insights (planned view, needs ~14 days of data)

### 🧠 Daily Coach
- On-demand AI analysis of the current day: intake vs. targets, key micronutrients, supplements
- Receives today's energy/sleep check-in and 7-day averages, and connects them to the nutrition data
- 3–5 direct, practical recommendations for the rest of the day

### 🔬 Micronutrients View
- Every mineral and vitamin with a progress bar against personalized DRI (National Academies) / WHO limits
- Limits adjusted for sex, age, weight and goal (e.g. iron 18 mg for pre-menopausal women, fiber scaled to calories)
- Inverted color logic for nutrients to limit (sodium, sugar, saturated fat, trans fat)
- Supplement contributions included

### 💊 Supplements
- Reusable templates: name, brand, dosage, full per-dose micronutrient profile
- One-tap daily logging; logged supplements count toward all daily totals
- Edit / delete via swipe

### 📅 History
- All meals grouped by day, with daily calorie totals per section header
- Tap through to full meal detail; swipe to delete

### ⚖️ Weight Log
- Quick weight entry; current weight + total change stats
- Smoothed gradient area chart (Swift Charts)
- Updates the profile weight used in target calculations

### 👤 Profile & Targets
- Onboarding: name, age, sex, height, weight, default plate diameter, goal
- Goals: lose fat, maintain, recomp, gain muscle, gain weight
- Targets via Mifflin-St Jeor BMR × activity, goal-adjusted calories, protein per kg by goal (1.6–2.4 g/kg), carb floor of 130 g, calorie floor of 1200 kcal
- Settings: update weight, plate diameter and goal, with visual save confirmation

---

## Architecture

```
NutriTrack/
├── NutriTrackApp.swift          # App entry — light mode, orange tint, PendingMealStore injection
├── Persistence.swift            # CoreData stack
├── Domain/                      # Pure logic, no UI
│   ├── Goal.swift, Sex.swift
│   ├── NutritionCalculator.swift  # BMR/TDEE/macro targets
│   ├── NutrientLimits.swift       # Personalized DRI/WHO micro limits
│   └── NutrientValidator.swift    # 4-4-9 + cross-field + outlier validation
├── Models/
│   ├── NutritionAnalysis.swift    # nonisolated Codable/Sendable DTOs + GeminiError
│   ├── PendingMealStore.swift     # Background analysis queue (ObservableObject)
│   └── *+Extensions.swift         # CoreData entity helpers
├── Services/
│   ├── GeminiService.swift        # Builds request bodies and parses responses
│   ├── Background/                # Model requests through a background URLSession
│   └── Sync/                      # Optional sync of your own data to your own server
└── Views/
    ├── Home/        # Dashboard, check-in, rings, meal rows, detail, preview
    ├── Log/         # Camera/library capture
    ├── Coach/       # Daily AI coach
    ├── History/     # Day-grouped meal log
    ├── Micronutrients/
    ├── Supplements/
    ├── Weight/
    ├── Settings/
    └── Onboarding/
```

**CoreData entities**: `FoodEntry` (35+ nutrient attributes + photo + AI comment), `DailyCheckIn` (energy, sleep hours/quality, bedtime, wake time), `SupplementTemplate`, `SupplementLog`, `UserProfile`, `WeightEntry`.

**Concurrency**: Swift 6.2 with default MainActor isolation. `GeminiService` builds request bodies and parses responses; network calls go through a background `URLSession`, so analyses finish even when the app is suspended. DTOs are `nonisolated` + `Sendable`.

---

## Setup

1. Clone and open `NutriTrack.xcodeproj` in Xcode 26+
2. Get a free API key at [Google AI Studio](https://aistudio.google.com)
3. Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` and paste your key there (`Secrets.xcconfig` is gitignored — never commit a real key)
4. In Xcode: project icon → Info tab → Configurations → set `Secrets` as the configuration file for Debug and Release

Optional: to send your own data to a server you control, fill `SYNC_BASE_URL` and `SYNC_TOKEN` in `Secrets.xcconfig`. Leave them empty to keep sync off. In `.xcconfig` files `//` starts a comment, so write the URL as `https:/$()/your-host`.

5. Build & run on iOS 26+ (free Apple Developer account works — 7-day certificate, reinstall weekly)

## Testing

```bash
xcodebuild test -scheme NutriTrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NutriTrackTests
```

Around 580 unit tests cover the domain logic (targets, nutrient limits, validation, training plan, day colour and calibration, check-in), the model request and response handling, the background job queue, the sync encoder and restorer, and the CoreData migrations.

The optional server has its own tests:

```bash
cd server && python -m venv .venv && .venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest -q
```

## Accuracy

Measured against a USDA-based reference for a real meal (3 eggs in olive oil + bread + avocado):
- **Core macros** (kcal/protein/carbs/fat): ~5% mean deviation (~95% accuracy)
- **Micronutrients**: ~25% mean deviation (~75% accuracy) — excellent for single-ingredient-dominant nutrients, weaker for nutrients accumulated from many small sources

The validation engine guarantees internal consistency; real-world accuracy depends on the model and improves with descriptive notes and the plate-diameter reference. Values are estimates — use trends, not single-day absolutes, for health decisions.

## Roadmap

- Insights view: energy vs. nutrition/sleep correlations (needs ~14 days of check-in data)
- Meal editing after save
- Photo storage optimization (thumbnail compression for entries older than 30 days)
- Barcode scanning, Apple Health integration, widgets

---

## Optional sync server

`server/` is a small FastAPI service (Docker) that receives your own records with a bearer token and lets the app restore them after a reinstall. Create `server/.env` with `NUTRITRACK_TOKEN=` followed by a long random string (the same value as `SYNC_TOKEN` in the app), then run `docker compose up -d --build`. It binds to `127.0.0.1` only: put it behind a private network or a reverse proxy with HTTPS.

## License

MIT — see [LICENSE](LICENSE).

*Nutritional values are AI estimates and not medical advice.*
