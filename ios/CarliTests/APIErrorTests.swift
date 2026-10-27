import Foundation
import Testing
@testable import Carli

struct APIErrorTests {
    @Test func offlineHasConnectionMessage() {
        #expect(APIError.offline.message(fallback: "x") == "No se puede conectar con el servidor.")
    }

    @Test func throttledHasWaitMessage() {
        #expect(APIError(status: 429).message(fallback: "x").hasPrefix("Demasiados intentos"))
    }

    @Test func validationErrorWinsOverMessage() {
        let body = Data(#"{"message":"The given data was invalid.","errors":{"email":["Credenciales incorrectas."]}}"#.utf8)
        #expect(APIError.from(status: 422, body: body).message(fallback: "x") == "Credenciales incorrectas.")
    }

    @Test func serverErrorUsesFallback() {
        let body = Data(#"{"message":"Server Error"}"#.utf8)
        #expect(APIError.from(status: 500, body: body).message(fallback: "fallback") == "fallback")
    }
}

struct LaunchTimingTests {
    @Test func eyesCloseMidBlink() {
        #expect(LaunchView.eyeOpenness(0.35) < 0.01)
        #expect(LaunchView.eyeOpenness(0.1) == 1)
    }

    @Test func wordmarkFadesIn() {
        #expect(LaunchView.wordmark(0) == 0)
        #expect(LaunchView.wordmark(1) == 1)
    }
}
