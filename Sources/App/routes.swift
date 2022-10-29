import Fluent
import Vapor
import TelegramBotSDK

func routes(_ app: Application) throws {
    app.get { req in
        "It works!"
    }

    app.post("commends") { req async throws -> Vapor.Response in
        let update: Update = try req.content.decode(
            Update.self,
            using: JSONDecoder.custom(keys: .convertFromSnakeCase)
        )
        
        try await req.queue.dispatch(
            TelegramBotJob.self,
            update
        )

        return Response(
            status: HTTPResponseStatus.ok,
            body: "True"
        )
    }

}
