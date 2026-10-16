import Foundation

nonisolated struct NutrientInfo: Equatable, Sendable {
    let name: String
    let why: String
    let sources: String

    static func forLabel(_ label: String) -> NutrientInfo? {
        all[key(label)]
    }

    private static func key(_ label: String) -> String {
        label.lowercased()
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    static let all: [String: NutrientInfo] = [
        "calories": NutrientInfo(
            name: "Calories",
            why: "The energy you take in. Against what you spend, it decides whether weight goes up or down, and too little for too long drains training, sleep and hormones.",
            sources: "Everything you eat and drink except water."),
        "protein": NutrientInfo(
            name: "Protein",
            why: "Builds and repairs muscle, and protects it while you lose fat. It is also the most filling macronutrient.",
            sources: "Meat, fish, eggs, dairy, legumes, soy."),
        "carbohydrates": NutrientInfo(
            name: "Carbohydrates",
            why: "The main fuel for training and what refills muscle glycogen afterwards. The need goes up with the minutes you train.",
            sources: "Grains, potatoes, fruit, legumes, dairy."),
        "net carbs": NutrientInfo(
            name: "Net carbs",
            why: "Carbohydrates minus fiber: the part that is digested and raises blood glucose.",
            sources: "The same foods as carbohydrates, less in those rich in fiber."),
        "fiber": NutrientInfo(
            name: "Fiber",
            why: "Feeds gut bacteria, slows digestion, steadies blood glucose and helps cholesterol. Most people eat too little.",
            sources: "Vegetables, fruit, legumes, whole grains, nuts."),
        "sugar": NutrientInfo(
            name: "Sugar",
            why: "Fast energy with little else. Useful around long training; in excess it crowds out more nutritious food.",
            sources: "Sweets, soft drinks, juice, fruit, dairy."),
        "fat": NutrientInfo(
            name: "Fat",
            why: "Carries vitamins A, D, E and K and is the raw material for sex hormones. There is some evidence, from six small studies, that very low-fat diets lower testosterone in men.",
            sources: "Oils, nuts, fatty fish, meat, dairy, eggs."),
        "saturated fat": NutrientInfo(
            name: "Saturated fat",
            why: "Raises LDL cholesterol when intake is high, so it has a ceiling instead of a target: about 10% of your calories.",
            sources: "Fatty meat, butter, cheese, coconut and palm oil."),
        "monounsaturated fat": NutrientInfo(
            name: "Monounsaturated fat",
            why: "The main fat of olive oil and nuts. Replacing saturated fat with it improves cholesterol.",
            sources: "Olive oil, avocado, almonds, hazelnuts."),
        "polyunsaturated fat": NutrientInfo(
            name: "Polyunsaturated fat",
            why: "Includes the essential fats your body cannot make, omega-3 and omega-6.",
            sources: "Fish, seeds, walnuts, vegetable oils."),
        "trans fat": NutrientInfo(
            name: "Trans fat",
            why: "Raises LDL and lowers HDL cholesterol. There is no amount worth eating, so the goal is as close to zero as possible.",
            sources: "Some fried and industrial baked foods; small natural amounts in dairy and beef."),
        "omega-3": NutrientInfo(
            name: "Omega-3",
            why: "Essential fats used in cell membranes, the brain and the control of inflammation. The long forms, EPA and DHA, come almost only from fish.",
            sources: "Oily fish; flax, chia and walnuts for the plant form."),
        "alcohol": NutrientInfo(
            name: "Alcohol",
            why: "Seven calories per gram with no nutrients. It also worsens sleep and recovery, which is why it is counted apart.",
            sources: "Beer, wine, spirits."),
        "sodium": NutrientInfo(
            name: "Sodium",
            why: "Controls fluid balance and blood pressure. Too much raises blood pressure; long sweaty sessions increase the need.",
            sources: "Salt, bread, cured meat, cheese, processed food."),
        "potassium": NutrientInfo(
            name: "Potassium",
            why: "Works against sodium on blood pressure and is needed for muscle and nerve signals. Most people fall short.",
            sources: "Potatoes, legumes, fruit, vegetables, dairy."),
        "calcium": NutrientInfo(
            name: "Calcium",
            why: "Bone structure and muscle contraction. Bone health matters more as your training load goes up.",
            sources: "Dairy, fortified drinks, sardines with bones, kale."),
        "iron": NutrientInfo(
            name: "Iron",
            why: "Carries oxygen in blood and muscle. Low iron limits endurance and the body's response to altitude.",
            sources: "Red meat, liver, legumes, spinach; vitamin C helps absorb the plant form."),
        "zinc": NutrientInfo(
            name: "Zinc",
            why: "Needed for immunity and wound healing. Phytate in whole grains and legumes lowers how much of it is absorbed.",
            sources: "Red meat, shellfish, legumes, seeds."),
        "magnesium": NutrientInfo(
            name: "Magnesium",
            why: "Used in energy production and in muscle and nerve function. Intake is often below the recommendation.",
            sources: "Nuts, seeds, legumes, whole grains, dark leafy greens."),
        "phosphorus": NutrientInfo(
            name: "Phosphorus",
            why: "Part of bone and of ATP, the energy currency of the cell. It is rarely low; it is tracked to see the balance with calcium.",
            sources: "Meat, dairy, fish, legumes."),
        "selenium": NutrientInfo(
            name: "Selenium",
            why: "Part of the enzymes that protect cells from oxidation and that activate thyroid hormone.",
            sources: "Brazil nuts, fish, eggs, meat."),
        "copper": NutrientInfo(
            name: "Copper",
            why: "Helps the body use iron and build connective tissue.",
            sources: "Liver, shellfish, nuts, cocoa."),
        "vitamin a": NutrientInfo(
            name: "Vitamin A",
            why: "Vision, immunity and skin. It is stored in the liver, so very high intakes from liver or supplements can be harmful.",
            sources: "Liver, eggs, dairy; carrots, sweet potato and greens as carotenoids."),
        "vitamin c": NutrientInfo(
            name: "Vitamin C",
            why: "Builds collagen, supports immunity and helps absorb iron from plants.",
            sources: "Citrus, peppers, kiwi, berries, broccoli."),
        "vitamin d": NutrientInfo(
            name: "Vitamin D",
            why: "Calcium absorption and bone and muscle function. Food provides little; most of it comes from sun on the skin.",
            sources: "Oily fish, eggs, fortified foods."),
        "vitamin e": NutrientInfo(
            name: "Vitamin E",
            why: "Protects the fats in cell membranes from oxidation.",
            sources: "Nuts, seeds, vegetable oils."),
        "vitamin k": NutrientInfo(
            name: "Vitamin K",
            why: "Needed for blood clotting and for building bone.",
            sources: "Leafy greens, broccoli, fermented foods."),
        "b1 thiamine": NutrientInfo(
            name: "Vitamin B1 (thiamine)",
            why: "Turns carbohydrate into energy. The need goes up with carbohydrate intake and training.",
            sources: "Pork, whole grains, legumes."),
        "b2 riboflavin": NutrientInfo(
            name: "Vitamin B2 (riboflavin)",
            why: "Part of the enzymes that release energy from food.",
            sources: "Dairy, eggs, meat, almonds."),
        "b3 niacin": NutrientInfo(
            name: "Vitamin B3 (niacin)",
            why: "Part of NAD, the molecule that moves energy around every cell.",
            sources: "Meat, fish, peanuts, whole grains."),
        "b5 pantothenic": NutrientInfo(
            name: "Vitamin B5 (pantothenic acid)",
            why: "Needed to burn fat and carbohydrate for energy and to build cholesterol and steroid hormones.",
            sources: "Meat, eggs, mushrooms, avocado."),
        "b6": NutrientInfo(
            name: "Vitamin B6",
            why: "Protein metabolism and the making of neurotransmitters and haemoglobin.",
            sources: "Poultry, fish, potatoes, bananas, chickpeas."),
        "b12": NutrientInfo(
            name: "Vitamin B12",
            why: "Red blood cells and nerves. It is found only in animal foods and fortified products.",
            sources: "Meat, fish, eggs, dairy."),
        "folate b9": NutrientInfo(
            name: "Folate (B9)",
            why: "Making new cells, red blood cells included. It works together with B12.",
            sources: "Leafy greens, legumes, liver, fortified grains.")
    ]
}
