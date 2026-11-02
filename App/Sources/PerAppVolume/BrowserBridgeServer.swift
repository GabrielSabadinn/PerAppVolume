import Foundation
import Network

final class BrowserBridgeServer {
    static let port: UInt16 = 47635
    private static let keepaliveInterval: TimeInterval = 20

    var onTabs: ((String, [BrowserTab]) -> Void)?
    var onDisconnect: ((String) -> Void)?

    private let token: String
    private let queue = DispatchQueue(label: "com.gabi.perappvolume.bridge")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: BridgeClient] = [:]

    init(token: String) {
        self.token = token
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: BrowserBridgeServer.port)!)
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        queue.async {
            self.clients.values.forEach { $0.close() }
            self.clients = [:]
            self.listener?.cancel()
            self.listener = nil
        }
    }

    func sendGain(_ gain: Float, tabID: Int, browserBundleID: String) {
        queue.async {
            self.clients.values
                .filter { $0.browserBundleID == browserBundleID }
                .forEach { $0.send(OutboundMessage(type: "gain", tabId: tabID, gain: gain)) }
        }
    }

    private func accept(_ connection: NWConnection) {
        let client = BridgeClient(connection: connection, queue: queue, token: token)
        client.onTabs = { [weak self] bundleID, tabs in self?.onTabs?(bundleID, tabs) }
        client.onAuthenticated = { [weak self, weak client] bundleID in
            self?.clients.values.filter { $0 !== client && $0.browserBundleID == bundleID }.forEach { $0.close() }
        }
        client.onClose = { [weak self, weak client] in
            guard let self, let client else { return }
            self.clients[ObjectIdentifier(client)] = nil
            if let bundleID = client.browserBundleID, !self.clients.values.contains(where: { $0.browserBundleID == bundleID }) {
                self.onDisconnect?(bundleID)
            }
        }
        clients[ObjectIdentifier(client)] = client
        client.start(keepalive: BrowserBridgeServer.keepaliveInterval)
    }
}

private struct InboundTab: Decodable {
    let id: Int
    let title: String
    let host: String
    let favicon: String
    let playing: Bool
    let gain: Float
    let control: Bool?
    let tracked: Int?
}

private struct InboundMessage: Decodable {
    let type: String
    let token: String?
    let browser: String?
    let tabs: [InboundTab]?
}

private struct OutboundMessage: Encodable {
    let type: String
    var tabId: Int? = nil
    var gain: Float? = nil
}

private final class BridgeClient {
    var onTabs: ((String, [BrowserTab]) -> Void)?
    var onAuthenticated: ((String) -> Void)?
    var onClose: (() -> Void)?
    private(set) var browserBundleID: String?

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let token: String
    private var keepalive: DispatchSourceTimer?
    private var closed = false

    init(connection: NWConnection, queue: DispatchQueue, token: String) {
        self.connection = connection
        self.queue = queue
        self.token = token
    }

    func start(keepalive interval: TimeInterval) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.finish()
            default: break
            }
        }
        connection.start(queue: queue)
        receive()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self, self.browserBundleID != nil else { return }
            self.send(OutboundMessage(type: "ping"))
        }
        timer.resume()
        keepalive = timer
    }

    func send(_ message: OutboundMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    func close() {
        connection.cancel()
    }

    private func receive() {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, let message = try? JSONDecoder().decode(InboundMessage.self, from: data) {
                self.handle(message)
            }
            if error == nil, !self.closed {
                self.receive()
            } else {
                self.finish()
            }
        }
    }

    private func handle(_ message: InboundMessage) {
        guard let browserBundleID else {
            authenticate(message)
            return
        }
        guard message.type == "tabs", let tabs = message.tabs else { return }
        DiagnosticsLog.write("\(browserBundleID) tabs: " + tabs.map { "\($0.id) \($0.host) playing=\($0.playing) control=\($0.control ?? false) tracked=\($0.tracked ?? 0) gain=\($0.gain)" }.joined(separator: " | "))
        onTabs?(browserBundleID, tabs.map { tab in
            BrowserTab(browserBundleID: browserBundleID, tabID: tab.id, title: tab.title, host: tab.host, faviconURL: URL(string: tab.favicon), isPlaying: tab.playing, hasControl: tab.control ?? false, gain: tab.gain)
        })
    }

    private func authenticate(_ message: InboundMessage) {
        guard message.type == "hello", message.token == token, let name = message.browser, let bundleID = BrowserIdentity.bundleID(forClientName: name) else {
            close()
            return
        }
        browserBundleID = bundleID
        DiagnosticsLog.write("\(bundleID) connected")
        onAuthenticated?(bundleID)
        send(OutboundMessage(type: "welcome"))
    }

    private func finish() {
        guard !closed else { return }
        closed = true
        keepalive?.cancel()
        DiagnosticsLog.write("\(browserBundleID ?? "unauthenticated") disconnected")
        onClose?()
    }
}
