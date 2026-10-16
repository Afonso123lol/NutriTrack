import CoreData

extension UserProfile {
    var sexEnum: Sex {
        get { Sex(rawValue: sex ?? "male") ?? .male }
        set { sex = newValue.rawValue }
    }

    var goalEnum: Goal {
        get { Goal(rawValue: goal ?? "maintain") ?? .maintain }
        set { goal = newValue.rawValue }
    }

    func setBirthDate(_ date: Date, now: Date = Date()) {
        birthDate = date
        age = Int16(BirthDate.age(bornOn: date, now: now))
    }

    @discardableResult
    func refreshAge(now: Date = Date()) -> Bool {
        guard let birthDate else { return false }
        let years = Int16(BirthDate.age(bornOn: birthDate, now: now))
        guard years != age else { return false }
        age = years
        return true
    }

    var macroTargets: MacroTargets { TargetService.currentTargets(for: self) }

    var sleepNeed: Double { SleepNeed.resolved(sleepNeedHours) }

    var yellowModeValue: YellowMode { YellowMode(rawValue: yellowMode ?? "") ?? .suggest }

    var userProfileData: UserProfileData {
        let targets = macroTargets
        return UserProfileData(
            goal: goalEnum.displayName,
            sex: sexEnum.displayName,
            age: Int(age),
            weightKg: weightKg,
            targetCalories: targets.calories,
            targetProteinG: targets.proteinG,
            targetCarbsG: targets.carbsG,
            targetFatG: targets.fatG
        )
    }
}
