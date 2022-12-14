import Vapor
import TelegramBotSDK
import Fluent
import FluentPostgresDriver

public func configureTelegramBot(_ app: Application, bot: TelegramBot) throws {

    // Create Date Formatter once
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM/dd"

    guard let webhookURLString = Environment.get("TELEGRAM_WEBHOOK_URL") else {
        throw Error.webhookURLNotFound
    }
    // set up webhook
    bot.setWebhookAsync(url: webhookURLString)

    // config telegram bot
    let router = app.telegramRouter

    let budgetForMonth: Decimal = 30000

    let listRouterKey = "📜 list"
    let budgetLeftRouterKey = "💰 budget left"
    let settleSpendingsRouterKey = "🤑 settle spendings"

    router[listRouterKey, [.caseSensitive]] = { [weak app] context in
        guard let app = app else {
            return false
        }
        Spending
            .query(on: app.db)
            .filter(\.$createdAt >= Date().startOfMonth())
            .filter(\.$createdAt <= Date().endOfMonth())
            .sort(\.$createdAt)
            .all()
            .whenSuccess { spendings in
                let results: [String] = spendings.compactMap {
                    var result = ""
                    if let date = $0.createdAt {
                        result.append(contentsOf: dateFormatter.string(from: date) + " ")
                    }
                    result.append(contentsOf: $0.identity.rawValue + " ")
                    result.append(contentsOf: $0.title + " ")
                    result.append(contentsOf: $0.cost)
                    return result
                }

                let veryFirstDate = spendings.first?.createdAt ?? Date()

                guard let range = Calendar.current.range(of: .day, in: .month, for: Date()) else {
                    return
                }
                let numDays = range.count

                let dateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: veryFirstDate)
                let day = dateComponents.day!

                let spentDay = Decimal(numDays - day + 1)
                let proportionalBudget = spentDay / Decimal(numDays) * budgetForMonth

                let total: Decimal = spendings.reduce(0) { $0 + (Decimal(string: $1.cost) ?? 0) }
                var displayString = results.joined(separator: "\n")
                displayString.append("\n\n📌 Total spending: \(total.intValue)")
                displayString.append("\n👉 \((proportionalBudget - total).intValue) left.")
                context.respondAsync(displayString)
            }
        return true
    }

    router[budgetLeftRouterKey, [.caseSensitive]] = { [weak app] context in
        guard let app = app else {
            return false
        }

        Spending
            .query(on: app.db)
            .filter(\.$createdAt >= Date().startOfMonth())
            .filter(\.$createdAt <= Date().endOfMonth())
            .field(\.$cost)
            .field(\.$createdAt)
            .field(\.$identity)
            .sort(\.$createdAt)
            .all()
            .whenSuccess { spendings in
                guard spendings.isEmpty == false,
                      let veryFirstDate = spendings.first?.createdAt else {
                    context.respondAsync("Spendings not found.")
                    return
                }
                let totalSpent: Decimal = spendings.reduce(0) { $0 + (Decimal(string: $1.cost) ?? 0) }
                guard let range = Calendar.current.range(of: .day, in: .month, for: Date()) else {
                    return
                }
                let numDays = range.count

                let dateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: veryFirstDate)
                let day = dateComponents.day!

                let currentDateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
                let currentDateDay = currentDateComponents.day!

                let spentDay = Decimal(numDays - day + 1)
                let proportionalBudget = spentDay / Decimal(numDays) * budgetForMonth

                let avgLeft = (proportionalBudget - totalSpent) / Decimal(numDays - currentDateDay)

                var andrewSpent: Decimal = 0
                var vivianSpent: Decimal = 0
                for spending in spendings {
                    switch spending.identity {
                    case .andrew:
                        andrewSpent += (Decimal(string: spending.cost) ?? 0)
                    case .vivian:
                        vivianSpent += (Decimal(string: spending.cost) ?? 0)
                    }
                }

                var display = "Already spent \(totalSpent.intValue) currently!"
                display.append("\nWe can only spend \(avgLeft.intValue) each day left in current month.")
                display.append("\n\(Identity.vivian.rawValue) spent \(vivianSpent.intValue)/\((budgetForMonth / 3).intValue).")
                display.append("\n\(Identity.andrew.rawValue) spent \(andrewSpent.intValue)/\((budgetForMonth / 3 * 2).intValue).")

                context.respondAsync(display)
            }
        return true
    }

    router[settleSpendingsRouterKey, [.caseSensitive]] = { [weak app] context in
        guard let app = app else {
            return false
        }

        Spending
            .query(on: app.db)
            .filter(\.$createdAt >= Date().startOfPreviousMonth())
            .filter(\.$createdAt <= Date().endOfPreviousMonth())
            .field(\.$cost)
            .field(\.$createdAt)
            .field(\.$identity)
            .sort(\.$createdAt)
            .all()
            .whenSuccess { spendings in
                guard spendings.isEmpty == false,
                      let veryFirstDate = spendings.first?.createdAt else {
                    context.respondAsync("Spendings not found.")
                    return
                }
                let totalSpent: Decimal = spendings.reduce(0) { $0 + (Decimal(string: $1.cost) ?? 0) }
                guard let range = Calendar.current.range(of: .day, in: .month, for: Date()) else {
                    return
                }
                let numDays = range.count

                let dateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: veryFirstDate)
                let day = dateComponents.day!

                let currentDateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
                let currentDateDay = currentDateComponents.day!

                let spentDay = Decimal(numDays - day + 1)
                let proportionalBudget = spentDay / Decimal(numDays) * budgetForMonth

                let avgLeft = (proportionalBudget - totalSpent) / Decimal(numDays - currentDateDay)

                var andrewSpent: Decimal = 0
                var vivianSpent: Decimal = 0
                for spending in spendings {
                    switch spending.identity {
                    case .andrew:
                        andrewSpent += (Decimal(string: spending.cost) ?? 0)
                    case .vivian:
                        vivianSpent += (Decimal(string: spending.cost) ?? 0)
                    }
                }

                var display = "Last most spent \(totalSpent.intValue)!"
                display.append("\nVivian part should be \((totalSpent / 3).intValue)")
                display.append("\nAndrew part should be \((totalSpent / 3 * 2).intValue)")
                display.append("\nWe can only spend \(avgLeft.intValue) each day left in current month.")
                display.append("\n\(Identity.vivian.rawValue) spent \(vivianSpent.intValue)/\((budgetForMonth / 3).intValue).")
                display.append("\n\(Identity.andrew.rawValue) spent \(andrewSpent.intValue)/\((budgetForMonth / 3 * 2).intValue).")
                let vivianOverSpent = (vivianSpent - (totalSpent / 3))
                if vivianOverSpent > 0 {
                    display.append("\n\nAndrew should give \(vivianOverSpent.intValue) to Vivian.")
                }

                let andrewOverSpent = (andrewSpent - (totalSpent / 3 * 2))
                if andrewOverSpent > 0 {
                    display.append("\n\nVivian should give \(andrewOverSpent.intValue) to Andrew.")
                }
                context.respondAsync(display)
            }
        return true
    }

    router["start", [.slashRequired, .caseSensitive]] = { context in
        let button1 = KeyboardButton(text: listRouterKey)
        let button2 = KeyboardButton(text: budgetLeftRouterKey)
        let button3 = KeyboardButton(text: settleSpendingsRouterKey)
        let markup = ReplyKeyboardMarkup(
            keyboard: [
                [button1, button2, button3],
            ],
            resizeKeyboard: true,
            oneTimeKeyboard: false,
            selective: false
        )
        context.respondAsync(
            "Welcome to use Co-Spending!",
            disableNotification: true,
            replyMarkup: .replyKeyboardMarkup(markup)
        )
        return true
    }

    router.partialMatch = { _ in false }

    router.unmatched = nil

    router.unsupportedContentType = nil

    print("Ready to accept commands")
}
