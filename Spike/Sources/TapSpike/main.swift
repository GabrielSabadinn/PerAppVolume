import CoreAudio
import Foundation

struct Options {
    var bundleFilter = ""
    var gain: Float = 0.3
    var seconds = 20.0
    var bufferFrames: UInt32 = 256
    var listOnly = false

    init(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--bundle": bundleFilter = iterator.next() ?? ""
            case "--gain": gain = Float(iterator.next() ?? "") ?? gain
            case "--seconds": seconds = Double(iterator.next() ?? "") ?? seconds
            case "--buffer": bufferFrames = UInt32(iterator.next() ?? "") ?? bufferFrames
            case "--list": listOnly = true
            default: break
            }
        }
    }
}

func describe(_ format: AudioStreamBasicDescription) -> String {
    let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0 ? "interleaved" : "non-interleaved"
    let float = format.mFormatFlags & kAudioFormatFlagIsFloat != 0 ? "float" : "int"
    return "\(Int(format.mSampleRate))Hz \(format.mChannelsPerFrame)ch \(format.mBitsPerChannel)bit \(float) \(interleaved)"
}

func listProcesses() throws -> [AudioProcess] {
    let processes = try AudioProcess.all()
    Log.write("process objects: \(processes.count)")
    for process in processes where process.isRunningOutput || !process.bundleID.isEmpty {
        Log.write("  pid=\(process.pid) output=\(process.isRunningOutput ? "yes" : "no ") bundle=\(process.bundleID.isEmpty ? "-" : process.bundleID) name=\(process.processName)")
    }
    return processes
}

func selectTarget(from processes: [AudioProcess], filter: String) -> AudioProcess? {
    let emitting = processes.filter(\.isRunningOutput)
    guard !filter.isEmpty else { return emitting.first }
    return processes.first { $0.bundleID.localizedCaseInsensitiveContains(filter) || $0.processName.localizedCaseInsensitiveContains(filter) }
}

func run(options: Options) throws {
    Log.write("--- TapSpike start pid=\(getpid()) gain=\(options.gain) seconds=\(options.seconds) filter='\(options.bundleFilter)'")
    let processes = try listProcesses()
    if options.listOnly { return }

    guard let target = selectTarget(from: processes, filter: options.bundleFilter) else {
        Log.write("RESULT: no target process found (filter='\(options.bundleFilter)')")
        return
    }
    Log.write("target: pid=\(target.pid) bundle=\(target.bundleID) name=\(target.processName) runningOutput=\(target.isRunningOutput)")

    let output = try OutputDevice.systemDefault()
    Log.write("default output: '\(output.name)' uid=\(output.uid) rate=\(Int(output.sampleRate)) inputStreams=\(output.inputStreamCount)")

    let tapStarted = Date()
    let tap = try ProcessTap(process: target)
    Log.write("tap created in \(Int(Date().timeIntervalSince(tapStarted) * 1000))ms id=\(tap.id) uid=\(tap.uid) format=\(describe(tap.format))")

    let aggregate = try AggregateDevice(output: output, tap: tap)
    Log.write("aggregate created id=\(aggregate.id) bufferFrames=\(aggregate.bufferFrameSize)")
    do {
        try aggregate.setBufferFrameSize(options.bufferFrames)
        Log.write("buffer frames set to \(aggregate.bufferFrameSize)")
    } catch {
        Log.write("buffer frame size change failed: \(error)")
    }
    Log.write("aggregate latency=\(aggregate.latencyFrames) frames, safetyOffset=\(aggregate.safetyOffsetFrames) frames")

    let mixer = GainMixer(gain: options.gain, tapBufferOffset: output.inputStreamCount)
    try aggregate.start { _, inputData, _, outputData, _ in
        mixer.render(input: inputData, output: outputData)
    }
    Log.write("IO running, applying gain \(options.gain) for \(options.seconds)s")

    let cleanup = {
        aggregate.destroy()
        tap.destroy()
        Log.write("cleanup done: aggregate and tap destroyed")
    }
    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signal(SIGINT, SIG_IGN)
    signalSource.setEventHandler { cleanup(); exit(0) }
    signalSource.resume()

    let deadline = Date().addingTimeInterval(options.seconds)
    var lastCallbackCount = 0
    while Date() < deadline {
        Thread.sleep(forTimeInterval: 1)
        let peaks = mixer.drainPeaks()
        let callbacks = mixer.callbackCount
        Log.write(String(format: "tick callbacks=%d (+%d) inBuffers=%d outBuffers=%d inPeak=%.3f outPeak=%.3f", callbacks, callbacks - lastCallbackCount, mixer.inputBufferCount, mixer.outputBufferCount, peaks.input, peaks.output))
        lastCallbackCount = callbacks
    }
    cleanup()
    Log.write("RESULT: OK callbacks=\(mixer.callbackCount)")
}

do {
    try run(options: Options(arguments: CommandLine.arguments))
} catch {
    Log.write("RESULT: FAILED \(error)")
    exit(1)
}
