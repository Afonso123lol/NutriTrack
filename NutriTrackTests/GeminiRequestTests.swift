import XCTest
@testable import NutriTrack

final class GeminiRequestTests: XCTestCase {

    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func envelope(answer: String, thought: String? = nil) throws -> Data {
        var parts: [[String: Any]] = []
        if let thought { parts.append(["text": thought, "thought": true]) }
        parts.append(["text": answer])
        return try JSONSerialization.data(withJSONObject: ["candidates": [["content": ["parts": parts]]]])
    }

    private let summary = DailySummary(calories: 1200, proteinG: 90, carbsG: 120, fatG: 40, fiberG: 18,
                                       omega3G: 1.1, ironMg: 9, zincMg: 7, magnesiumMg: 250,
                                       vitaminDUg: 4, calciumMg: 600, supplementsDescription: "Magnesium")
    private let profile = UserProfileData(goal: "Lose fat", sex: "Male", age: 25, weightKg: 80,
                                          targetCalories: 2400, targetProteinG: 160,
                                          targetCarbsG: 250, targetFatG: 70)

    func testEndpointRequestCarriesKeyInHeaderNotURL() {
        let request = GeminiService.endpointRequest(apiKey: "abc", modelID: "gemini-3.5-flash-lite")
        XCTAssertEqual(request?.url?.absoluteString,
                       "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "x-goog-api-key"), "abc")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request?.httpMethod, "POST")
    }

    func testModelAlternatesInPairsStartingWithThePrimary() {
        XCTAssertEqual(GeminiService.primaryModelID, "gemini-3.5-flash-lite")
        XCTAssertEqual(GeminiService.reserveModelID, "gemma-4-31b-it")
        XCTAssertEqual((0...7).map(GeminiService.modelID(forAttempt:)), [
            "gemini-3.5-flash-lite", "gemini-3.5-flash-lite", "gemma-4-31b-it", "gemma-4-31b-it",
            "gemini-3.5-flash-lite", "gemini-3.5-flash-lite", "gemma-4-31b-it", "gemma-4-31b-it"
        ])
    }

    func testAnalysisBodyCarriesImageAndConfig() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x01])
        let body = try json(GeminiService.analysisRequestBody(jpegData: jpeg, note: "fried in oil", plateDiameterCm: 26))
        let parts = try XCTUnwrap(((body["contents"] as? [[String: Any]])?.first?["parts"]) as? [[String: Any]])
        let inline = try XCTUnwrap(parts.last?["inline_data"] as? [String: Any])
        XCTAssertEqual(inline["mime_type"] as? String, "image/jpeg")
        XCTAssertEqual(inline["data"] as? String, jpeg.base64EncodedString())
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains("fried in oil"))
        XCTAssertTrue(prompt.contains("26 cm"))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["maxOutputTokens"] as? Int, 8192)
    }

    func testCoachBodyCarriesSummaryAndConfig() throws {
        let body = try json(GeminiService.coachRequestBody(summary: summary, profile: profile, checkInSummary: "- Today: energy 4/5"))
        let text = try XCTUnwrap((((body["contents"] as? [[String: Any]])?.first?["parts"]) as? [[String: Any]])?.first?["text"] as? String)
        XCTAssertTrue(text.contains("Magnesium"))
        XCTAssertTrue(text.contains("energy 4/5"))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["maxOutputTokens"] as? Int, 4096)
    }

    func testScoreEvaluationBodyAsksForTwoComments() throws {
        let score = HealthScore(value: 70, components: [])
        let body = try json(GeminiService.scoreEvaluationRequestBody(sleep: score, readiness: score,
                                                                     daySummaryText: "Check-in: energy 4/5"))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains(#"{"sleepComment":"","readinessComment":""}"#))
        XCTAssertFalse(prompt.contains("dietComment"))
        XCTAssertTrue(prompt.contains("Check-in: energy 4/5"))
    }

    func testParseScoreEvaluationWithTwoComments() throws {
        let data = try envelope(answer: #"{"sleepComment":"a","readinessComment":"c"}"#, thought: "thinking")
        let texts = try GeminiService.parseScoreEvaluationResponse(data)
        XCTAssertEqual(texts.sleepComment, "a")
        XCTAssertEqual(texts.readinessComment, "c")
    }

    func testParseScoreEvaluationIgnoresTheDietCommentOfOlderJobs() throws {
        let data = try envelope(answer: #"{"sleepComment":"a","dietComment":"b","readinessComment":"c"}"#)
        XCTAssertEqual(try GeminiService.parseScoreEvaluationResponse(data).readinessComment, "c")
    }

    func testParseScoreEvaluationMissingCommentThrows() throws {
        let data = try envelope(answer: #"{"sleepComment":"a"}"#)
        XCTAssertThrowsError(try GeminiService.parseScoreEvaluationResponse(data))
    }

    func testParseCoachSkipsThoughts() throws {
        let data = try envelope(answer: "Eat more fibre.", thought: "Planning the answer")
        XCTAssertEqual(try GeminiService.parseCoachResponse(data), "Eat more fibre.")
    }

    func testParseCoachThrowsWhenOnlyThoughts() throws {
        let data = try JSONSerialization.data(withJSONObject: ["candidates": [["content": ["parts": [["text": "x", "thought": true]]]]]])
        XCTAssertThrowsError(try GeminiService.parseCoachResponse(data))
    }

    func testParseNutritionNotFoundThrowsNotFood() throws {
        let data = try envelope(answer: #"{"isFood":false,"dishName":"Not food"}"#)
        XCTAssertThrowsError(try GeminiService.parseNutritionResponse(data)) { error in
            guard case GeminiError.notFood = error else { return XCTFail("expected notFood, got \(error)") }
        }
    }

    func testParseNutritionReadsDish() throws {
        let answer = #"{"isFood":true,"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,"fatG":12,"saturatedFatG":3.5,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,"sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,"magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,"vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,"vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,"vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}"#
        let analysis = try GeminiService.parseNutritionResponse(try envelope(answer: answer, thought: "Step 1"))
        XCTAssertEqual(analysis.dishName, "Grilled chicken with rice")
    }

    func testDescriptionBodyCarriesOnlyTextWithTheMeal() throws {
        let body = try json(GeminiService.descriptionRequestBody(description: "2 chorizo rolls and a 500 ml Monster"))
        let parts = try XCTUnwrap(((body["contents"] as? [[String: Any]])?.first?["parts"]) as? [[String: Any]])
        XCTAssertEqual(parts.count, 1)
        XCTAssertNil(parts.first?["inline_data"])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains("MEAL DESCRIPTION: 2 chorizo rolls and a 500 ml Monster"))
        XCTAssertTrue(prompt.contains("there is no photo"))
        XCTAssertEqual(prompt.components(separatedBy: #""alcoholG":0"#).count, 3)
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["maxOutputTokens"] as? Int, 8192)
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
    }

    func testDescriptionDropsControlCharactersAndIsCapped() throws {
        let long = "a\u{0007}b" + String(repeating: "x", count: 2000)
        let body = try json(GeminiService.descriptionRequestBody(description: long))
        let parts = try XCTUnwrap(((body["contents"] as? [[String: Any]])?.first?["parts"]) as? [[String: Any]])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains("MEAL DESCRIPTION: ab" + String(repeating: "x", count: 998) + "\n"))
    }

    func testAnalysisPromptAsksForAlcohol() throws {
        let body = try json(GeminiService.analysisRequestBody(jpegData: Data([0xFF, 0xD8]), note: nil, plateDiameterCm: nil))
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertEqual(prompt.components(separatedBy: #""alcoholG":0"#).count, 3)
        XCTAssertTrue(prompt.contains("alcoholG*7"))
    }

    func testDietEvaluationBodyAsksForOneComment() throws {
        let score = HealthScore(value: 64, components: [ScoreComponent(label: "Protein", score: 0.5, weight: 0.3)])
        let body = try json(GeminiService.dietEvaluationRequestBody(diet: score,
                                                                    daySummaryText: "Calories: 1800 / 2400 kcal target"))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains("64/100"))
        XCTAssertTrue(prompt.contains("Protein: 50%"))
        XCTAssertTrue(prompt.contains("Calories: 1800 / 2400 kcal target"))
        XCTAssertTrue(prompt.contains(#"{"dietComment":""}"#))
    }

    func testParseDietEvaluation() throws {
        let data = try envelope(answer: #"{"dietComment":"Good protein."}"#, thought: "thinking")
        XCTAssertEqual(try GeminiService.parseDietEvaluationResponse(data), "Good protein.")
    }

    func testParseDietEvaluationWithoutCommentThrows() throws {
        XCTAssertThrowsError(try GeminiService.parseDietEvaluationResponse(try envelope(answer: #"{"dietComment":""}"#)))
        XCTAssertThrowsError(try GeminiService.parseDietEvaluationResponse(try envelope(answer: "not json")))
    }
}
