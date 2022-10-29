//
//  TelegramBot+Application.swift
//  
//
//  Created by Andrew Wang on 2022/10/29.
//

import Foundation
import Vapor
import TelegramBotSDK

extension Application {
    
    public var telegramBot: TelegramBot {
        self.bot.storage.bot
    }
    
    public var telegramRouter: TelegramBotSDK.Router {
        self.bot.storage.router
    }
    
    public var bot: Bot {
        .init(application: self)
    }
    
    public struct Bot {
        final class Storage {
            let bot: TelegramBot
            let router: TelegramBotSDK.Router
            
            init(token: String) {
                bot = TelegramBot(token: token)
                router = Router(bot: bot)
            }
        }
        
        let application: Application
        
        struct LifecycleHandler: Vapor.LifecycleHandler {
            func shutdown(_ application: Application) {
                try! application.threadPool.syncShutdownGracefully()
            }
        }
        
        struct Key: StorageKey {
            typealias Value = Storage
        }
        
        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("Core not configured. Configure with app.bot.initialize()")
            }
            return storage
        }
        
        public func initialize(token: String) {
            application.storage[Key.self] = .init(token: token)
            application.lifecycle.use(LifecycleHandler())
        }
    }
    
}

