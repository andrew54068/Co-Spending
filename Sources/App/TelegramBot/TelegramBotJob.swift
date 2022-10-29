//
//  TelegramBotJob.swift
//
//
//  Created by Andrew Wang on 2022/9/9.
//

import Foundation
import Vapor
import TelegramBotSDK
import Queues
import Fluent
import FluentPostgresDriver

public struct TelegramBotJob: AsyncJob {
    public typealias Payload = Update

    public func dequeue(_ context: Queues.QueueContext, _ payload: Update) async throws {
        let app = context.application
        let bot = app.telegramBot
        let router = context.application.telegramRouter
        let update = payload

        guard try router.process(update: update) == false else {
            return
        }

        handleCallbackQuery(
            bot: bot,
            query: update.callbackQuery,
            database: app.db
        )

        guard let fromId = (update.message?.from?.id ?? update.editedMessage?.from?.id) else {
            app.console.info(String(describing: Error.chetIdNotFound))
            throw Error.chetIdNotFound
        }

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

        let markup = InlineKeyboardMarkup(inlineKeyboard: [
            [
                InlineKeyboardButton(text: "delete", callbackData: "\(message.messageId)"),
            ],
        ])

        if isEdited {
            let existingSpending = try await Spending.query(on: app.db)
                .filter(\.$messageId == spending.messageId)
                .first()

            if existingSpending != nil {
                try await spending.update(on: app.db)
            } else {
                try await spending.save(on: app.db)
            }
        } else {
            try await spending.save(on: app.db)
        }

        var reply: String
        if isEdited {
            reply = "✅ Edited"
        } else {
            reply = "✅ Record"
        }

        reply.append(" successfully! \(spending.identity.rawValue) spend \(spending.cost) on \(spending.title)")

        bot.sendMessageAsync(
            chatId: .chat(fromId),
            text: reply,
            replyToMessageId: message.messageId,
            replyMarkup: ReplyMarkup.inlineKeyboardMarkup(markup)
        )
        app.console.info(reply)
        app.console.info("save spending \(spending.title)!")
    }

    func error(
        _ context: QueueContext,
        _ error: Error,
        _ payload: Update
    ) async throws {
        let app = context.application
        let bot = app.telegramBot
        guard let fromId = (payload.message?.from?.id ?? payload.editedMessage?.from?.id) else {
            app.console.info(String(describing: Error.chetIdNotFound))
            throw Error.chetIdNotFound
        }
        bot.sendMessageAsync(
            chatId: .chat(fromId),
            text: "❗️ Failed! \(error.localizedDescription)"
        )
        throw error
    }
}

private func handleCallbackQuery(
    bot: TelegramBot,
    query: CallbackQuery?,
    database: Database
) {
    guard let query = query,
          let queryString = query.data,
          let messageId = Int(queryString),
          let replyMessageId = query.message?.messageId else {
        return
    }

    Spending.query(on: database)
        .filter(\.$messageId == messageId)
        .first()
        .whenSuccess { spending in
            if let spending = spending {
                _ = spending.delete(on: database)
                    .map { _ in
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
                    }
            } else {
                bot.sendMessageAsync(
                    chatId: .chat(query.from.id),
                    text: "❗️ Failed! \(Error.spendingNotExistInDB.localizedDescription)"
                )
            }
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
