import Vapor
import Fluent
import FluentPostgresDriver
import Queues
import QueuesRedisDriver
import Redis

// configures your application
public func configure(_ app: Application) throws {

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

    app.migrations.add(CreateSpending(), to: DatabaseID.psql)

    try app.autoMigrate().wait()

    let hostname = "redis"

    let config = try RedisConfiguration(
        url: "redis://\(hostname):6379",
        pool: .init(
            maximumConnectionCount: .maximumPreservedConnections(5),
            minimumConnectionCount: 1,
            initialConnectionBackoffDelay: .minutes(1),
            connectionRetryTimeout: .minutes(1)
        )
    )

    app.queues.use(
        .redis(
            config
        )
    )

    // Register jobs
    let telegramBotJob = TelegramBotJob()
    app.queues.add(telegramBotJob)

    try app.queues.startInProcessJobs()

    // register routes
    try routes(app)
}
