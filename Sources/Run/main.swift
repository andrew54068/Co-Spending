import App
import Vapor
import Jobs

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)

Jobs.oneoff {
    try configureTelegramBot(app)
}

try app.run()
