import App
import Vapor
import Queues
import QueuesRedisDriver
import TelegramBotSDK

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }

guard let token: String = Environment.get("TelegramBotToken") else {
    fatalError("Telegram bot token not found")
}
app.bot.initialize(token: token)
try configureTelegramBot(app, bot: app.telegramBot)
try configure(app)

try app.run()
