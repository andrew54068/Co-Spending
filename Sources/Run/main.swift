import App
import Vapor
import Queues
import QueuesRedisDriver
import TelegramBotSDK

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)

if let token: String = Environment.get("TelegramBotToken") {
    let bot = TelegramBot(token: token)
    let router: TelegramBotSDK.Router = try configureTelegramBot(app, bot: bot)
    let job = TelegramBotJob(
        app: app,
        bot: bot,
        router: router
    )
    try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
    app.queues.schedule(job)
        .everySecond()
}

try app.queues.startScheduledJobs()
try app.run()
