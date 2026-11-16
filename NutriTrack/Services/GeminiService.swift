import Foundation
import UIKit

nonisolated enum GeminiService {
    nonisolated static let primaryModelID = "gemini-3.5-flash-lite"
    nonisolated static let reserveModelID = "gemma-4-31b-it"
    nonisolated static let attemptsPerModel = 2
    nonisolated static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    nonisolated private static func sanitised(_ text: String, limit: Int) -> String {
        String(text.unicodeScalars.filter { $0.value >= 32 }.prefix(limit).map(Character.init))
    }

    nonisolated private static let analysisRules = """
KEY RULES:
- Never return zero for a nutrient that is realistically present (e.g. eggs always have B12, selenium, vitamin D)
- Oils and cooking fats must be included — they are the largest source of error in visual estimation
- Use the USDA standard reference: eggs ~143kcal/100g, olive oil ~884kcal/100g, etc.
- Micronutrients must reflect USDA values for the identified components, not a visual guess
- The returned numbers must be internally consistent: calories equals proteinG*4 + carbsG*4 + fatG*9 + alcoholG*7 within 5%; sugarG and fiberG never exceed carbsG; saturatedFatG + monounsaturatedFatG + polyunsaturatedFatG + transFatG never exceeds fatG
- vitaminAUg is in µg RAE (retinol activity equivalents)
- alcoholG is grams of pure ethanol from alcoholic drinks (beer ~4 g per 100 ml, wine ~10 g per 100 ml, spirits ~32 g per 100 ml); 0 when there is none

CRITICAL OUTPUT RULE: Work through all steps and consistency checks internally — do NOT write out your reasoning. Your entire response must be the final JSON object alone, nothing before or after it.

If no food detected, return exactly:
{"isFood":false,"dishName":"Not food","comment":"","calories":0,"proteinG":0,"carbsG":0,"fatG":0,"saturatedFatG":0,"monounsaturatedFatG":0,"polyunsaturatedFatG":0,"transFatG":0,"omega3G":0,"fiberG":0,"sugarG":0,"alcoholG":0,"sodiumMg":0,"potassiumMg":0,"calciumMg":0,"ironMg":0,"zincMg":0,"magnesiumMg":0,"phosphorusMg":0,"seleniumUg":0,"copperUg":0,"vitaminAUg":0,"vitaminCMg":0,"vitaminDUg":0,"vitaminEMg":0,"vitaminKUg":0,"vitaminB1Mg":0,"vitaminB2Mg":0,"vitaminB3Mg":0,"vitaminB5Mg":0,"vitaminB6Mg":0,"vitaminB12Ug":0,"folateUg":0}

Otherwise return ONLY a valid JSON object (numbers, not strings). The "comment" field must be 1-2 sentences in the same language the user wrote their note (default English), briefly assessing the meal's nutritional quality — highlight the main positives and one area to watch. Be specific, not generic:
{"isFood":true,"dishName":"","comment":"","calories":0,"proteinG":0,"carbsG":0,"fatG":0,"saturatedFatG":0,"monounsaturatedFatG":0,"polyunsaturatedFatG":0,"transFatG":0,"omega3G":0,"fiberG":0,"sugarG":0,"alcoholG":0,"sodiumMg":0,"potassiumMg":0,"calciumMg":0,"ironMg":0,"zincMg":0,"magnesiumMg":0,"phosphorusMg":0,"seleniumUg":0,"copperUg":0,"vitaminAUg":0,"vitaminCMg":0,"vitaminDUg":0,"vitaminEMg":0,"vitaminKUg":0,"vitaminB1Mg":0,"vitaminB2Mg":0,"vitaminB3Mg":0,"vitaminB5Mg":0,"vitaminB6Mg":0,"vitaminB12Ug":0,"folateUg":0}
"""

    nonisolated private static func buildDescriptionPrompt(description: String) -> String {
        """
You are a registered dietitian with expertise in nutritional analysis.

TASK: The user describes a meal in words; there is no photo. Estimate its nutrition using a structured 3-step approach.

MEAL DESCRIPTION: \(sanitised(description, limit: 1000))

STEP 1 — IDENTIFICATION: List every food and drink in the description separately, with the quantity stated. If the description is not about food or drink, stop and return the not-food JSON.

STEP 2 — WEIGHT ESTIMATION: Use the quantities, sizes and nutrition values the user gives exactly as written. Where no quantity is given, assume one typical serving. For branded or packaged products use the manufacturer's label values for the stated size.

STEP 3 — NUTRITION CALCULATION: For each component, apply the values the user states or the product label when available; otherwise apply USDA FoodData Central reference values per 100g, scaled to the weight. Sum all components. Use the preparation method described; if none, assume typical home cooking. Scale every per-100g or per-100ml value to the amount actually eaten, including the number of units. European labels state salt, not sodium: sodiumMg is salt in grams times 400.

\(analysisRules)
"""
    }

    nonisolated private static func buildAnalysisPrompt(note: String?, plateDiameterCm: Double?) -> String {
        var context = ""
        if let diameter = plateDiameterCm, diameter > 0 {
            context += " The plate diameter is \(Int(diameter)) cm — use this as a scale reference for all portion estimates."
        } else {
            context += " There is no plate size reference: the food may be in a bowl, a container, a package or in the hand. Count whole units where possible (fruit, slices, pieces) and read the net weight on any visible package; never assume a plate size."
        }
        if let note = note, !note.isEmpty {
            let sanitised = sanitised(note, limit: 500)
            if !sanitised.isEmpty {
                context += " User note: \(sanitised)"
            }
        }

        return """
You are a registered dietitian with expertise in nutritional analysis.

TASK: Analyze this food image using a structured 3-step approach.

STEP 1 — IDENTIFICATION: List every visible food component separately (e.g. "2 large eggs", "1 slice sourdough bread 40g", "15ml olive oil"). If the image contains no food at all, stop and return the not-food JSON.

STEP 2 — WEIGHT ESTIMATION: Estimate the weight in grams of each component using visual cues.\(context) Be realistic — do not underestimate oils, sauces, or cooking fats.

STEP 3 — NUTRITION CALCULATION: For each component, apply USDA FoodData Central reference values per 100g, then scale to the estimated weight. Sum all components. Use the specific preparation method described in the user note; if no note, assume typical home cooking (e.g. eggs fried/scrambled in oil unless clearly boiled).

\(analysisRules)
"""
    }

    nonisolated private static func buildAnalysisRequest(base64Image: String, prompt: String) -> [String: Any] {
        return [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 8192,
                "responseMimeType": "application/json"
            ]
        ]
    }

    nonisolated private static func buildCoachPrompt(summary: DailySummary, profile: UserProfileData,
                                  checkInSummary: String? = nil) -> String {
        let checkInSection = checkInSummary.map { "\n        ENERGY & SLEEP:\n        \($0)\n" } ?? ""
        return """
        You are a personal nutrition coach with sports science expertise. Analyze today's nutritional intake and provide concise, actionable recommendations.

        USER PROFILE:
        - Goal: \(profile.goal)
        - Sex: \(profile.sex), Age: \(profile.age), Weight: \(profile.weightKg)kg
        - Daily targets: \(profile.targetCalories) kcal, protein \(profile.targetProteinG)g, carbs \(profile.targetCarbsG)g, fat \(profile.targetFatG)g

        TODAY'S INTAKE SO FAR:
        - Calories: \(summary.calories) / \(profile.targetCalories) kcal
        - Protein: \(summary.proteinG)g | Carbs: \(summary.carbsG)g | Fat: \(summary.fatG)g
        - Fiber: \(summary.fiberG)g | Omega-3: \(summary.omega3G)g
        - Key micronutrients: Iron \(summary.ironMg)mg, Zinc \(summary.zincMg)mg, Magnesium \(summary.magnesiumMg)mg, Vitamin D \(summary.vitaminDUg)µg, Calcium \(summary.calciumMg)mg
        - Supplements logged today: \(summary.supplementsDescription)
        \(checkInSection)
        Provide 3–5 specific recommendations for the rest of today. Be direct and practical. If something looks good, say so briefly. Focus on what matters most for their goal. If energy or sleep data is present, connect it to the nutrition data where relevant.
        """
    }

    nonisolated static func analysisJPEG(from image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale < 1.0 {
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
            return resized.jpegData(compressionQuality: 0.6)
        }
        return image.jpegData(compressionQuality: 0.6)
    }

    nonisolated static func parseNutritionResponse(_ data: Data) throws -> NutritionAnalysis {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parsingError("Unexpected response structure")
        }
        let rawText = Self.answerText(fromParts: parts)
        let jsonString = extractJSONObject(from: rawText)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.parsingError("Could not encode response text")
        }
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("GeminiService parse failure — raw response prefix: \(String(rawText.prefix(400)))")
            throw GeminiError.parsingError("Invalid JSON structure")
        }
        if let isFood = dict["isFood"] as? Bool, !isFood {
            throw GeminiError.notFood
        }
        // Rebuild JSON from dict to fix any encoding issues in string fields (e.g. comment)
        guard let cleanData = try? JSONSerialization.data(withJSONObject: dict) else {
            throw GeminiError.parsingError("Could not re-serialize response")
        }
        do {
            let decoded = try JSONDecoder().decode(NutritionAnalysis.self, from: cleanData)
            return NutrientValidator.validate(decoded)
        } catch {
            throw GeminiError.parsingError("Invalid JSON: \(error.localizedDescription)")
        }
    }

    nonisolated static func answerText(fromParts parts: [[String: Any]]) -> String {
        parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    nonisolated static func configuredAPIKey(in bundle: Bundle = .main) -> String? {
        guard let key = bundle.infoDictionary?["GEMINI_API_KEY"] as? String, !key.isEmpty else { return nil }
        return key
    }

    nonisolated static func modelID(forAttempt attempt: Int) -> String {
        (attempt / attemptsPerModel).isMultiple(of: 2) ? primaryModelID : reserveModelID
    }

    nonisolated static func endpointRequest(apiKey: String, modelID: String) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(modelID):generateContent") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        return request
    }

    nonisolated static func descriptionRequestBody(description: String) throws -> Data {
        let body: [String: Any] = [
            "contents": [["parts": [["text": buildDescriptionPrompt(description: description)]]]],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 8192,
                "responseMimeType": "application/json"
            ]
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    nonisolated static func analysisRequestBody(jpegData: Data, note: String?, plateDiameterCm: Double?) throws -> Data {
        let prompt = buildAnalysisPrompt(note: note, plateDiameterCm: plateDiameterCm)
        let body = buildAnalysisRequest(base64Image: jpegData.base64EncodedString(), prompt: prompt)
        return try JSONSerialization.data(withJSONObject: body)
    }

    nonisolated static func coachRequestBody(summary: DailySummary, profile: UserProfileData,
                                             checkInSummary: String?) throws -> Data {
        let prompt = buildCoachPrompt(summary: summary, profile: profile, checkInSummary: checkInSummary)
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.7, "maxOutputTokens": 4096]
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    nonisolated static func parseCoachResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parsingError("Could not extract coach response")
        }
        let text = answerText(fromParts: parts)
        guard !text.isEmpty else {
            throw GeminiError.parsingError("Could not extract coach response")
        }
        return text
    }

    nonisolated private static func extractJSONObject(from text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // The model may prepend reasoning text; take the last balanced {...} block
        var lastBlock: Substring?
        var depth = 0
        var blockStart: String.Index?
        for i in stripped.indices {
            switch stripped[i] {
            case "{":
                if depth == 0 { blockStart = i }
                depth += 1
            case "}":
                depth -= 1
                if depth == 0, let start = blockStart {
                    lastBlock = stripped[start...i]
                } else if depth < 0 {
                    depth = 0
                }
            default:
                break
            }
        }
        if let block = lastBlock { return String(block) }

        guard let start = stripped.firstIndex(of: "{"),
              let end = stripped.lastIndex(of: "}") else { return stripped }
        return String(stripped[start...end])
    }
}
