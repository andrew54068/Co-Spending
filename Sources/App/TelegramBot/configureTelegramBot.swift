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
        context.respondAsync(results.joined(separator: "\n"))
        return true
    }

    router["start", [.slashRequired, .caseSensitive]] = { context in
        let button = KeyboardButton(text: "📜 list")
        let markup = ReplyKeyboardMarkup(
            keyboard: [[button]],
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

    bot.deleteMessageAsync(
        chatId: .chat(query.from.id),
        messageId: replyMessageId
    )

    bot.deleteMessageAsync(
        chatId: .chat(query.from.id),
        messageId: messageId
    )

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
        if let number = Decimal(string: $1) {
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
