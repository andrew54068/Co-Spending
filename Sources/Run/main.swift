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

let token1 = "5421614145"
let token2 = "AAEWkGQOmqNRZU3V0mUT4PQ8rfC45NfP0sE"

let bot = TelegramBot(token: [token1, token2].joined(separator: ":"))
let router: TelegramBotSDK.Router = try configureTelegramBot(app, bot: bot)
let job = TelegramBotJob(
    app: app,
    bot: bot,
    router: router
)
try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
app.queues.schedule(job)
    .everySecond()

try app.queues.startScheduledJobs()
try app.run()
