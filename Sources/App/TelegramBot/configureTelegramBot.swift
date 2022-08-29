import Vapor
import TelegramBotSDK
import Fluent
import FluentPostgresDriver

public func configureTelegramBot(_ app: Application) async throws {

    // Create Date Formatter once
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM/dd"

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

    app.migrations.add(CreateSpending(), to: DatabaseID.psql)

    try await app.autoMigrate()

    // config telegram bot
    let bot = TelegramBot(token: "5421614145:AAEWkGQOmqNRZU3V0mUT4PQ8rfC45NfP0sE")

    let router = Router(bot: bot)

    let budgetForMonth: Decimal = 30000

    router["📜 list", [.caseSensitive]] = { [weak app] context in
        guard let app = app else {
            return false
        }
        let spendings: [Spending] = try Spending
            .query(on: app.db)
            .all()
            .wait()
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
            return false
        }
        let numDays = range.count

        let dateComponents = Calendar.current.dateComponents(in: TimeZone.current, from: veryFirstDate)
        let day = dateComponents.day!

        let spentDay = Decimal(numDays - day + 1)
        let proportionalBudget = spentDay / Decimal(numDays) * budgetForMonth

        let total: Decimal = spendings.reduce(0) { $0 + (Decimal(string: $1.cost) ?? 0) }
        var displayString = results.joined(separator: "\n")
        displayString.append("\n\n📌 Total spending: \(total.stringValue)")
        displayString.append("\n👉 \((proportionalBudget - total).intValue) left.")
        context.respondAsync(displayString)
        return true
    }

    router["💰 budget left", [.caseSensitive]] = { [weak app] context in
        guard let app = app else {
            return false
        }

        let spendings: [Spending] = try Spending
            .query(on: app.db)
            .filter(\.$createdAt >= Date().startOfMonth())
            .filter(\.$createdAt <= Date().endOfMonth())
            .field(\.$cost)
            .field(\.$createdAt)
            .field(\.$identity)
            .sort(\.$createdAt)
            .all()
            .wait()
        guard spendings.isEmpty == false,
              let veryFirstDate = spendings.first?.createdAt else {
            context.respondAsync("Spendings not found.")
            return true
        }
        let totalSpent: Decimal = spendings.reduce(0) { $0 + (Decimal(string: $1.cost) ?? 0) }
        guard let range = Calendar.current.range(of: .day, in: .month, for: Date()) else {
            return false
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

        var display = "Already spent \(totalSpent.stringValue)!"
        display.append("\nWe can only spend \(avgLeft.intValue) each day left in current month.")
        display.append("\n\(Identity.vivian.rawValue) spent \(vivianSpent.intValue).")
        display.append("\n\(Identity.andrew.rawValue) spent \(andrewSpent.intValue).")

        context.respondAsync(display)
        return true
    }

    router["start", [.slashRequired, .caseSensitive]] = { context in
        let button1 = KeyboardButton(text: "📜 list")
        let button2 = KeyboardButton(text: "💰 budget left")
        let markup = ReplyKeyboardMarkup(
            keyboard: [
                [button1, button2],
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

    router.unmatched = { _ in false }

    router.unsupportedContentType = nil

    print("Ready to accept commands")
    while let update = bot.nextUpdateSync() {

        guard try router.process(update: update) == false else {
            continue
        }

        await handleCallbackQuery(
            bot: bot,
            query: update.callbackQuery,
            database: app.db
        )

        guard let fromId = (update.message?.from?.id ?? update.editedMessage?.from?.id) else {
            app.console.info(Error.chetIdNotFound.localizedDescription)
            continue
        }

        do {
            var message: Message
            var isEdited: Bool = false
            if let msg = update.message {
                message = msg
                isEdited = false
            } else if let msg = update.editedMessage {
                message = msg
                isEdited = true
            } else {
                throw Error.messageNotFound
            }

            let spending = try parseInput(message: message)

            let reply: String

            if isEdited {
                if let spending = try await Spending.query(on: app.db)
                    .filter(\.$messageId == spending.messageId)
                    .first() {
                    try await spending.update(on: app.db)
                } else {
                    try await spending.save(on: app.db)
                }
                reply = "✅ Edited successfully! \(spending.identity.rawValue) spend \(spending.cost) on \(spending.title)"
            } else {
                try await spending.save(on: app.db)
                reply = "✅ Record successfully! \(spending.identity.rawValue) spend \(spending.cost) on \(spending.title)"
            }

            let markup = InlineKeyboardMarkup(inlineKeyboard: [
                [
                    InlineKeyboardButton(text: "delete", callbackData: "\(message.messageId)"),
                ],
            ])

            bot.sendMessageAsync(
                chatId: .chat(fromId),
                text: reply,
                replyToMessageId: message.messageId,
                replyMarkup: ReplyMarkup.inlineKeyboardMarkup(markup)
            )
            app.console.info("save spending \(spending.title)!")
        } catch {
            bot.sendMessageAsync(
                chatId: .chat(fromId),
                text: "❗️ Failed! \(error.localizedDescription)"
            )
            continue
        }
    }

}

private func handleCallbackQuery(
    bot: TelegramBot,
    query: CallbackQuery?,
    database: Database
) async {

    guard let query = query,
          let queryString = query.data,
          let messageId = Int(queryString),
          let replyMessageId = query.message?.messageId else {
        return
    }

    do {
        if let spending = try await Spending.query(on: database)
            .filter(\.$messageId == messageId)
            .first() {
            try await spending.delete(on: database)

            bot.answerCallbackQueryAsync(
                callbackQueryId: query.id,
                text: "🔥 Delete succeed!",
                showAlert: false
            )

            bot.deleteMessageAsync(
                chatId: .chat(query.from.id),
                messageId: replyMessageId
            )

            bot.deleteMessageAsync(
                chatId: .chat(query.from.id),
                messageId: messageId
            )
        } else {
            throw Error.spendingNotExistInDB
        }
    } catch {
        bot.sendMessageAsync(
            chatId: .chat(query.from.id),
            text: "❗️ Failed! \(error.localizedDescription)"
        )
    }
}

private func parseInput(message: Message) throws -> Spending {
    guard let from = message.from,
          let text = message.text else {
        throw Error.messageNotFound
    }
    guard let identity = Identity(id: from.id) else {
        throw Error.identityInvalid
    }

    let splitMessages = text.components(separatedBy: [",", "，", " "]).filter { $0.isEmpty == false }
    var elements = splitMessages.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard elements.count == 2 else {
        throw Error.inputInvalid
    }

    let costs: [(Int, Decimal)] = elements.enumerated().compactMap {
        if Int($1) != nil,
           let number = Decimal(string: $1) {
            return ($0, number)
        } else {
            return nil
        }
    }
    guard costs.count == 1,
          let cost = costs.first else {
        throw Error.costShouldBeExectlyOne
    }

    elements.remove(at: cost.0)
    guard let title = elements.first else {
        throw Error.spendingTitleNotFound
    }

    return Spending(
        messageId: message.messageId,
        title: String(title),
        cost: cost.1,
        identity: identity
    )
}
