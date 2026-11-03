import AVFoundation
import Foundation

// MARK: - Patch JSON Models

public enum CPSJSONValue: Codable {
    case float(Float)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let f = try? container.decode(Float.self) {
            self = .float(f)
        } else if let i = try? container.decode(Int.self) {
            self = .float(Float(i))
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .float(0.0)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .float(let f):
            try container.encode(f)
        case .string(let s):
            try container.encode(s)
        }
    }

    public var floatValue: Float? {
        switch self {
        case .float(let f): return f
        case .string(let s): return Float(s)
        }
    }
}

public struct CPSPatchOperation: Codable {
    public let op: String
    public let args: [String]?
    public let `var`: String?
    public let scope: String?
    public let `class`: String?
    public let target: String?
    public let message: String?
    public let src: String?
    public let src_scope: String?
    public let src_out_pin: Int?
    public let dst: String?
    public let dst_scope: String?
    public let dst_in_pin: Int?
    public let value: CPSJSONValue?
    public let inlet: Int?
}

public struct CPSPatchDefinition: Codable {
    public let movie: String
    public let script_num: Int?
    public let member_num: Int?
    public let member_name: String?
    public let globals: [String]?
    public let locals: [String]?
    public let ordered_operations: [CPSPatchOperation]
}

// MARK: - WAV (.hrs) Loader & Cache

public final class CPSWavSample {
    public let path: String
    public let sampleRate: Int
    public let channels: Int
    public let bitsPerSample: Int
    public let frameCount: Int
    public let left: [Float]
    public let right: [Float]

    public init(
        path: String,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int,
        left: [Float],
        right: [Float]
    ) {
        self.path = path
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.frameCount = min(left.count, right.count)
        self.left = left
        self.right = right
    }
}

public final class CPSWavCache {
    public let xtrasURL: URL
    private var cache: [String: CPSWavSample?] = [:]
    private let lock = NSLock()

    public init(xtrasURL: URL) {
        self.xtrasURL = xtrasURL
    }

    public var loadedSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.values.compactMap { $0 }.count
    }

    public var missingSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        var count = 0
        for (_, val) in cache where val == nil {
            count += 1
        }
        return count
    }

    public func sample(for rawRelativePath: String) -> CPSWavSample? {
        let normalized = Self.normalizeRelativePath(rawRelativePath)
        guard !normalized.isEmpty else { return nil }
        let key = normalized.lowercased()

        lock.lock()
        if let existing = cache[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let resolvedURL = resolveFileURL(relativePath: normalized)
        let loaded: CPSWavSample?
        if let url = resolvedURL {
            loaded = Self.loadWavFile(at: url, relativePath: normalized)
        } else {
            loaded = nil
        }

        lock.lock()
        cache[key] = loaded
        lock.unlock()
        return loaded
    }

    public static func normalizeRelativePath(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\\", with: "/")
        while s.hasPrefix("/") {
            s.removeFirst()
        }
        return s
    }

    private func resolveFileURL(relativePath: String) -> URL? {
        let directURL = xtrasURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return directURL
        }

        // Case-insensitive component resolution fallback
        let components = relativePath.split(separator: "/").map(String.init)
        var currentURL = xtrasURL
        let fm = FileManager.default
        for comp in components {
            let candidate = currentURL.appendingPathComponent(comp)
            if fm.fileExists(atPath: candidate.path) {
                currentURL = candidate
                continue
            }
            guard let entries = try? fm.contentsOfDirectory(atPath: currentURL.path) else {
                return nil
            }
            if let match = entries.first(where: { $0.caseInsensitiveCompare(comp) == .orderedSame }) {
                currentURL = currentURL.appendingPathComponent(match)
            } else {
                return nil
            }
        }
        return fm.fileExists(atPath: currentURL.path) ? currentURL : nil
    }

    public static func loadWavFile(at url: URL, relativePath: String) -> CPSWavSample? {
        guard let data = try? Data(contentsOf: url), data.count >= 44 else {
            return nil
        }

        return data.withUnsafeBytes { (rawBuf: UnsafeRawBufferPointer) -> CPSWavSample? in
            guard let base = rawBuf.baseAddress else { return nil }
            let totalBytes = rawBuf.count

            func readU16(_ offset: Int) -> UInt16 {
                guard offset + 2 <= totalBytes else { return 0 }
                return base.advanced(by: offset).assumingMemoryBound(to: UInt16.self).pointee.littleEndian
            }

            func readU32(_ offset: Int) -> UInt32 {
                guard offset + 4 <= totalBytes else { return 0 }
                var val: UInt32 = 0
                memcpy(&val, base.advanced(by: offset), 4)
                return UInt32(littleEndian: val)
            }

            func readFourCC(_ offset: Int) -> String {
                guard offset + 4 <= totalBytes else { return "" }
                let slice = UnsafeBufferPointer(
                    start: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self),
                    count: 4
                )
                return String(bytes: slice, encoding: .ascii) ?? ""
            }

            guard readFourCC(0) == "RIFF", readFourCC(8) == "WAVE" else {
                return nil
            }

            var audioFormat: Int = 1
            var numChannels: Int = 1
            var sampleRate: Int = 44100
            var bitsPerSample: Int = 16
            var dataOffset: Int = 0
            var dataSize: Int = 0

            var offset = 12
            while offset + 8 <= totalBytes {
                let chunkID = readFourCC(offset)
                let chunkSize = Int(readU32(offset + 4))
                let chunkDataStart = offset + 8
                if chunkID == "fmt " && chunkDataStart + 16 <= totalBytes {
                    audioFormat = Int(readU16(chunkDataStart))
                    numChannels = max(1, Int(readU16(chunkDataStart + 2)))
                    sampleRate = Int(readU32(chunkDataStart + 4))
                    bitsPerSample = Int(readU16(chunkDataStart + 14))
                } else if chunkID == "data" {
                    dataOffset = chunkDataStart
                    dataSize = min(chunkSize, totalBytes - chunkDataStart)
                    break
                }
                let paddedSize = chunkSize + (chunkSize & 1)
                if paddedSize < 0 || chunkDataStart + paddedSize <= offset {
                    break
                }
                offset = chunkDataStart + paddedSize
            }

            guard audioFormat == 1, dataOffset > 0, dataSize > 0 else {
                return nil
            }

            let bytesPerSample = max(1, bitsPerSample / 8)
            let bytesPerFrame = bytesPerSample * numChannels
            let frameCount = dataSize / bytesPerFrame
            guard frameCount > 0 else { return nil }

            var left = [Float](repeating: 0.0, count: frameCount)
            var right = [Float](repeating: 0.0, count: frameCount)

            let pcmPtr = base.advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)

            if bitsPerSample == 16 {
                if numChannels == 1 {
                    for i in 0..<frameCount {
                        let byteIdx = i * 2
                        let lo = UInt16(pcmPtr[byteIdx])
                        let hi = UInt16(pcmPtr[byteIdx + 1]) << 8
                        let sample = Float(Int16(bitPattern: lo | hi)) / 32768.0
                        left[i] = sample
                        right[i] = sample
                    }
                } else {
                    for i in 0..<frameCount {
                        let byteIdx = i * bytesPerFrame
                        let lLo = UInt16(pcmPtr[byteIdx])
                        let lHi = UInt16(pcmPtr[byteIdx + 1]) << 8
                        let rLo = UInt16(pcmPtr[byteIdx + 2])
                        let rHi = UInt16(pcmPtr[byteIdx + 3]) << 8
                        left[i] = Float(Int16(bitPattern: lLo | lHi)) / 32768.0
                        right[i] = Float(Int16(bitPattern: rLo | rHi)) / 32768.0
                    }
                }
            } else if bitsPerSample == 8 {
                if numChannels == 1 {
                    for i in 0..<frameCount {
                        let s = (Float(pcmPtr[i]) - 128.0) / 128.0
                        left[i] = s
                        right[i] = s
                    }
                } else {
                    for i in 0..<frameCount {
                        let byteIdx = i * bytesPerFrame
                        left[i] = (Float(pcmPtr[byteIdx]) - 128.0) / 128.0
                        right[i] = (Float(pcmPtr[byteIdx + 1]) - 128.0) / 128.0
                    }
                }
            } else {
                return nil
            }

            if sampleRate != 44100 && sampleRate > 0 && frameCount > 1 {
                let ratio = Double(sampleRate) / 44100.0
                let outFrames = max(1, Int(Double(frameCount) / ratio))
                var resampledLeft = [Float](repeating: 0.0, count: outFrames)
                var resampledRight = [Float](repeating: 0.0, count: outFrames)
                let maxIdx = frameCount - 1
                for i in 0..<outFrames {
                    let srcPos = Double(i) * ratio
                    let idx0 = min(maxIdx, Int(srcPos))
                    let idx1 = min(maxIdx, idx0 + 1)
                    let frac = Float(srcPos - Double(idx0))
                    resampledLeft[i] = left[idx0] + frac * (left[idx1] - left[idx0])
                    resampledRight[i] = right[idx0] + frac * (right[idx1] - right[idx0])
                }
                left = resampledLeft
                right = resampledRight
            }

            return CPSWavSample(
                path: relativePath,
                sampleRate: sampleRate,
                channels: numChannels,
                bitsPerSample: bitsPerSample,
                left: left,
                right: right
            )
        }
    }
}

// MARK: - Control Connection & Node Types

public struct CPSControlConnection {
    public unowned let dstNode: CPSNode
    public var dstInPin: Int
}

public enum CPSNodeKind: String {
    case button = "button"
    case numberField = "numberField"
    case fader = "fader"
    case constant = "constant"
    case order = "order"
    case floatNode = "float"
    case switchNode = "switch"
    case plus = "+"
    case multiply = "*"
    case minus = "-"
    case divide = "/"
    case pow = "pow"
    case exp = "exp"
    case lessOrEqual = "<="
    case equals = "=="
    case greater = ">"
    case greaterOrEqual = ">="
    case logicalAnd = "&&"
    case audioFromDisk = "audioFromDisk"
    case table = "table"
    case oscil = "oscil"
    case sinus = "sinus"
    case arand = "arand"
    case upsamp = "upsamp"
    case audioOut = "audioOut"
}

public final class CPSNode {
    public static let blockSize = 512
    public static let sampleRate = 44100.0

    public let id: Int
    public let kind: CPSNodeKind
    public let typeName: String

    // Dynamic pin counts matching CPSDistr.exe
    public var kinCount: Int
    public var koutCount: Int
    public var ainCount: Int
    public var aoutCount: Int

    // Control connections: indexed by outPin (0..9 corresponding to pins 40..49)
    public var controlOuts: [[CPSControlConnection]] = Array(repeating: [], count: 10)

    // Audio inputs: indexed by inPin (0..7 corresponding to pins 10..17)
    public var audioInputs: [(srcNode: CPSNode, srcOutIndex: Int)?] = Array(repeating: nil, count: 8)

    // Audio outputs: indexed by outPin (0..1 corresponding to pins 30..31)
    public var audioOutputs: [[Float]]

    // Recursion depth counter for propagateControl (matches CPSDistr.exe 0x4104d1 limit of 2)
    public var recursionDepth: Int = 0

    // _UP / _DWN conversate state machine
    public var upState: Int = 0
    public var faderConfigIndex: Int = 0

    // Value & control states
    public var value: Float = 0.0
    public var minVal: Float = 0.0
    public var maxVal: Float = 1.0
    public var in0: Float = 0.0
    public var in1: Float = 0.0
    public var result: Float = 0.0
    public var matched: Bool = false

    // switch state (CPSDistr.exe 0x4207f0: default matchVals[0] = 1.0, others 0.0; koutCount starts at 2)
    public var matchVals: [Float] = [1, 0, 0, 0, 0, 0, 0, 0]
    public var switchMatchedMask: UInt16 = 0

    // audioFromDisk state
    public var wavSlots: [CPSWavSample?] = []
    public var activeSlot: Int = 0
    public var playhead: Int = 0
    public var isPlaying: Bool = false
    public var loopMode: Int = 0 // 0 = one-shot, 1 = loop single, 2 = playlist
    public var lastSamplesPlayed: Float = 0.0

    // table state
    public var tableSamples: [Float] = CPSNode.defaultSineTable

    // oscil / sinus / arand / upsamp state
    public weak var wavetableNode: CPSNode?
    public var freqControl: Float = 440.0
    public var ampControl: Float = 1.0
    public var phase: Double = 0.0
    public var rngState: UInt32 = 0x1234_5678
    public var upsampCurrent: Float = 0.0
    public var upsampTarget: Float = 0.0
    public var upsampInitialized: Bool = false

    private static let defaultSineTable: [Float] = {
        let size = 1024
        return (0..<size).map { i in
            Float(Foundation.sin(2.0 * .pi * Double(i) / Double(size)))
        }
    }()

    public init(id: Int, kind: CPSNodeKind) {
        self.id = id
        self.kind = kind
        self.typeName = kind.rawValue

        switch kind {
        case .button, .numberField, .fader, .constant:
            self.kinCount = 1
            self.koutCount = 1
            self.ainCount = 0
            self.aoutCount = 0
        case .order:
            self.kinCount = 1
            self.koutCount = 2
            self.ainCount = 0
            self.aoutCount = 0
        case .floatNode:
            self.kinCount = 2
            self.koutCount = 1
            self.ainCount = 0
            self.aoutCount = 0
        case .exp:
            self.kinCount = 1
            self.koutCount = 1
            self.ainCount = 0
            self.aoutCount = 0
        case .switchNode:
            self.kinCount = 2
            self.koutCount = 2
            self.ainCount = 0
            self.aoutCount = 0
        case .plus, .multiply, .minus, .divide, .pow:
            self.kinCount = 3
            self.koutCount = 1
            self.ainCount = 0
            self.aoutCount = 0
            if kind == .divide {
                self.in1 = 0.001
            }
        case .lessOrEqual, .equals, .greater, .greaterOrEqual, .logicalAnd:
            self.kinCount = 3
            self.koutCount = 2
            self.ainCount = 0
            self.aoutCount = 0
        case .audioFromDisk:
            self.kinCount = 2
            self.koutCount = 0 // Incremented to 1 when "_UP" is received
            self.ainCount = 0
            self.aoutCount = 2
        case .table:
            self.kinCount = 0
            self.koutCount = 1
            self.ainCount = 0
            self.aoutCount = 0
        case .oscil:
            self.kinCount = 2
            self.koutCount = 0
            self.ainCount = 1
            self.aoutCount = 1
        case .sinus:
            self.kinCount = 1
            self.koutCount = 0
            self.ainCount = 0
            self.aoutCount = 1
        case .arand:
            self.kinCount = 0
            self.koutCount = 0
            self.ainCount = 1
            self.aoutCount = 1
        case .upsamp:
            self.kinCount = 2
            self.koutCount = 0
            self.ainCount = 0
            self.aoutCount = 1
        case .audioOut:
            self.kinCount = 0
            self.koutCount = 0
            self.ainCount = 2
            self.aoutCount = 2
        }

        let outBufCount = max(self.aoutCount, 2)
        self.audioOutputs = (0..<outBufCount).map { _ in
            [Float](repeating: 0.0, count: CPSNode.blockSize)
        }
    }

    public var isAudioNode: Bool {
        if aoutCount > 0 || ainCount > 0 {
            return true
        }
        return false
    }

    // MARK: Conversate

    public func conversate(_ rawCommand: String, wavCache: CPSWavCache) {
        let cmd = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if cmd == "_UP" {
            upState = 1
            faderConfigIndex = 0
            switch kind {
            case .audioFromDisk:
                if koutCount == 0 {
                    koutCount = 1
                }
            case .order:
                if koutCount < 9 {
                    koutCount += 1
                }
            case .switchNode:
                if koutCount < 9 {
                    koutCount += 1
                }
            default:
                break
            }
            return
        }
        if cmd == "_DWN" {
            upState = 0
            faderConfigIndex = 0
            return
        }

        switch kind {
        case .button, .numberField, .floatNode, .constant, .fader:
            let numStr: Substring
            if cmd.hasPrefix("R") || cmd.hasPrefix("r") || cmd.hasPrefix("I") || cmd.hasPrefix("i") {
                numStr = cmd.dropFirst()
            } else {
                numStr = Substring(cmd)
            }
            if let v = Float(numStr) {
                value = v
            }
        case .switchNode:
            let parts = cmd.split { $0 == "," || $0 == " " || $0 == "\t" }
            for (idx, part) in parts.enumerated() where idx < 8 {
                if let v = Float(part) {
                    matchVals[idx] = v
                }
            }
        case .audioFromDisk:
            if cmd.lowercased() == "clear" {
                wavSlots.removeAll()
                activeSlot = 0
                isPlaying = false
                playhead = 0
            } else if !cmd.isEmpty && cmd.lowercased() != "status" {
                let sample = wavCache.sample(for: cmd)
                wavSlots.append(sample)
            }
        case .table:
            let tokens = cmd.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            if tokens.count >= 2 && tokens[0].lowercased() == "harm" {
                let size = max(64, Int(tokens[1]) ?? 1024)
                let harmonics = tokens.dropFirst(2).compactMap { Double($0) }
                var buf = [Float](repeating: 0.0, count: size)
                for i in 0..<size {
                    var sum = 0.0
                    for (hIdx, amp) in harmonics.enumerated() where amp != 0.0 {
                        let harmonicNumber = Double(hIdx + 1)
                        sum += amp * Foundation.sin(2.0 * .pi * harmonicNumber * Double(i) / Double(size))
                    }
                    buf[i] = Float(sum)
                }
                tableSamples = buf
            }
        default:
            break
        }
    }

    // MARK: Control Input (kin) & Output (kout)

    /// Processes a control input value on `inPin` (0-based, corresponding to Pin 20 + inPin).
    /// Returns `true` if this node should immediately propagate its control outputs.
    public func kin(value val: Float, inPin: Int) -> Bool {
        switch kind {
        case .button, .numberField, .fader:
            if inPin == 0 {
                value = val
                return true
            }
            return false

        case .constant:
            if inPin == 0 {
                // Ignores incoming trigger value and emits stored constant
                return true
            } else {
                // CPSOBJkin(obj, newVal, 1) overwrites stored constant and emits it
                value = val
                return true
            }

        case .order:
            if inPin == 0 {
                value = val
                return true
            }
            return false

        case .floatNode:
            if inPin == 0 {
                // Pin 20: Cold store
                value = val
                return false
            } else if inPin >= 1 {
                // Pin 21+: Hot trigger
                return true
            }
            return false

        case .switchNode:
            if inPin == 0 {
                // Pin 20: Cold selector test value
                in0 = val
                return false
            } else if inPin == 1 {
                // Pin 21: Hot value to route
                value = val
                var mask: UInt16 = 0
                let numMatchPins = max(1, min(8, koutCount - 1))
                for i in 0..<numMatchPins {
                    if abs(in0 - matchVals[i]) < 1e-5 {
                        mask |= (1 << i)
                    }
                }
                if mask == 0 && koutCount >= 2 {
                    // Default / else branch on the last control output pin (koutCount - 1)
                    mask |= (1 << (koutCount - 1))
                }
                switchMatchedMask = mask
                return mask != 0
            }
            return false

        case .plus:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 { result = in0 + in1; return true }
            return false

        case .multiply:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 { result = in0 * in1; return true }
            return false

        case .minus:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 { result = in0 - in1; return true }
            return false

        case .divide:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 {
                if abs(val) > 1e-12 {
                    in1 = val
                }
                return false
            }
            if inPin == 2 {
                if abs(in1) > 1e-12 {
                    let r = in0 / in1
                    result = r.isFinite ? r : 0.0
                } else {
                    result = 0.0
                }
                return true
            }
            return false

        case .pow:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 {
                if (in0 == 0.0 && in1 <= 0.0) || (in0 < 0.0 && in1 != Foundation.floor(in1)) {
                    result = 0.0
                } else {
                    let r = Float(Foundation.pow(Double(in0), Double(in1)))
                    result = r.isFinite ? r : 0.0
                }
                return true
            }
            return false

        case .exp:
            if inPin == 0 {
                in0 = val
                let r = Float(Foundation.exp(Double(val)))
                result = r.isFinite ? r : 0.0
                return true
            }
            return false

        case .lessOrEqual:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 {
                matched = (in0 <= in1 + 1e-6)
                return true
            }
            return false

        case .equals:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 {
                matched = (abs(in0 - in1) < 1e-5)
                return true
            }
            return false

        case .greater:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 {
                matched = (in0 > in1 + 1e-6)
                return true
            }
            return false

        case .greaterOrEqual:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 { in1 = val; return false }
            if inPin == 2 {
                matched = (in0 >= in1 - 1e-6)
                return true
            }
            return false

        case .logicalAnd:
            if inPin == 0 { in0 = val; return false }
            if inPin == 1 {
                in1 = val
                matched = (abs(in0) > 1e-6 && abs(in1) > 1e-6)
                return true
            }
            if inPin == 2 {
                matched = (abs(in0) > 1e-6 && abs(in1) > 1e-6)
                return true
            }
            return false

        case .audioFromDisk:
            if inPin == 0 {
                // Pin 20: Sample index (1..N plays from beginning, 0 stops)
                let slotIdx = Int(val >= 0 ? (val + 0.5) : (val - 0.5))
                if slotIdx >= 1 && slotIdx <= wavSlots.count, wavSlots[slotIdx - 1] != nil {
                    activeSlot = slotIdx
                    playhead = 0
                    isPlaying = true
                } else {
                    isPlaying = false
                    activeSlot = 0
                    playhead = 0
                }
                return false
            } else if inPin == 1 {
                // Pin 21: Loop mode (0 = one-shot, 1 = loop single, 2 = playlist)
                loopMode = Int(val >= 0 ? (val + 0.5) : (val - 0.5))
                return false
            }
            return false

        case .oscil:
            if inPin == 1 {
                phase = 0.0
            }
            return false

        case .sinus:
            if inPin == 0 {
                freqControl = val
            }
            return false

        case .arand:
            return false

        case .upsamp:
            if inPin == 0 {
                upsampTarget = val
                if !upsampInitialized {
                    upsampCurrent = val
                    upsampInitialized = true
                }
            }
            return false

        case .table, .audioOut:
            return false
        }
    }

    /// Reads the control output on `outPin` (0-based, corresponding to Pin 40 + outPin).
    public func kout(outPin: Int) -> Float? {
        switch kind {
        case .button, .numberField, .fader, .constant, .floatNode:
            return outPin == 0 ? value : nil

        case .order:
            return (0..<koutCount).contains(outPin) ? value : nil

        case .switchNode:
            guard outPin >= 0 && outPin < koutCount else { return nil }
            return (switchMatchedMask & (1 << outPin)) != 0 ? value : nil

        case .plus, .multiply, .minus, .divide, .pow, .exp:
            return outPin == 0 ? result : nil

        case .lessOrEqual, .equals, .greater, .greaterOrEqual, .logicalAnd:
            if outPin == 0 {
                return matched ? in1 : nil
            } else if outPin == 1 {
                return !matched ? in1 : nil
            }
            return nil

        case .audioFromDisk:
            return (outPin == 0 && koutCount > 0) ? lastSamplesPlayed : nil

        case .table, .oscil, .sinus, .arand, .upsamp, .audioOut:
            return nil
        }
    }

    // MARK: Audio Block Processing (512 samples @ 44100 Hz)

    @inline(__always)
    private func sampleInput(_ index: Int, _ sampleIdx: Int) -> Float {
        guard let input = audioInputs[index] else { return 0.0 }
        return input.srcNode.audioOutputs[input.srcOutIndex][sampleIdx]
    }

    public func performBlock() {
        let n = CPSNode.blockSize
        switch kind {
        case .audioFromDisk:
            var samplesPlayed = 0
            if isPlaying, activeSlot >= 1, activeSlot <= wavSlots.count,
               let sample = wavSlots[activeSlot - 1], sample.frameCount > 0
            {
                let count = sample.frameCount
                var pos = playhead
                for i in 0..<n {
                    if pos >= count {
                        if loopMode == 1 {
                            pos = 0
                        } else if loopMode == 2 && !wavSlots.isEmpty {
                            activeSlot = (activeSlot % wavSlots.count) + 1
                            pos = 0
                            if wavSlots[activeSlot - 1] == nil {
                                isPlaying = false
                                for rem in i..<n {
                                    audioOutputs[0][rem] = 0.0
                                    audioOutputs[1][rem] = 0.0
                                }
                                break
                            }
                        } else {
                            isPlaying = false
                            for rem in i..<n {
                                audioOutputs[0][rem] = 0.0
                                audioOutputs[1][rem] = 0.0
                            }
                            break
                        }
                    }
                    audioOutputs[0][i] = sample.left[pos]
                    audioOutputs[1][i] = sample.right[pos]
                    pos += 1
                    samplesPlayed += 1
                }
                playhead = pos
                if loopMode == 0 && playhead >= count {
                    isPlaying = false
                }
            } else {
                for i in 0..<n {
                    audioOutputs[0][i] = 0.0
                    audioOutputs[1][i] = 0.0
                }
            }
            lastSamplesPlayed = Float(samplesPlayed)

        case .upsamp:
            let target = upsampTarget
            for i in 0..<n {
                audioOutputs[0][i] = target
            }
            upsampCurrent = target

        case .oscil:
            let tbl = wavetableNode?.tableSamples ?? CPSNode.defaultSineTable
            let tblSize = tbl.count
            guard tblSize > 0 else { return }
            let sizeDouble = Double(tblSize)
            let mask = tblSize - 1
            let isPow2 = (tblSize & mask) == 0
            let hasFreqAudio = (audioInputs[0] != nil)
            let invSR = sizeDouble / CPSNode.sampleRate

            var p = phase
            for i in 0..<n {
                let freq = hasFreqAudio ? sampleInput(0, i) : freqControl
                p = p.truncatingRemainder(dividingBy: sizeDouble)
                if p < 0 { p += sizeDouble }
                let idx0 = Int(p)
                let frac = Float(p - Double(idx0))
                let s0: Float
                let s1: Float
                if isPow2 {
                    s0 = tbl[idx0 & mask]
                    s1 = tbl[(idx0 + 1) & mask]
                } else {
                    let c0 = idx0 % tblSize
                    let c1 = (idx0 + 1) % tblSize
                    s0 = tbl[c0]
                    s1 = tbl[c1]
                }
                audioOutputs[0][i] = s0 + frac * (s1 - s0)
                p += Double(freq) * invSR
            }
            phase = p

        case .sinus:
            let invSR = 1.0 / CPSNode.sampleRate
            let freq = Double(freqControl)
            var p = phase
            for i in 0..<n {
                audioOutputs[0][i] = Float(Foundation.sin(2.0 * .pi * p))
                p += freq * invSR
                if p >= 1.0 || p < 0.0 {
                    p -= Foundation.floor(p)
                }
            }
            phase = p

        case .arand:
            var rng = rngState
            for i in 0..<n {
                let amp = sampleInput(0, i)
                rng = rng &* 1_664_525 &+ 1_013_904_223
                let r = Float(Int32(bitPattern: rng)) / 2_147_483_648.0
                audioOutputs[0][i] = r * amp
            }
            rngState = rng

        case .plus:
            if ainCount >= 2 {
                let count = min(ainCount, audioInputs.count)
                for i in 0..<n {
                    var sum: Float = 0.0
                    for ch in 0..<count where audioInputs[ch] != nil {
                        sum += sampleInput(ch, i)
                    }
                    audioOutputs[0][i] = sum
                }
            } else if ainCount == 1 {
                let c = in0
                for i in 0..<n {
                    audioOutputs[0][i] = sampleInput(0, i) + c
                }
            }

        case .multiply:
            if ainCount >= 2 {
                let count = min(ainCount, audioInputs.count)
                for i in 0..<n {
                    var prod: Float = 1.0
                    for ch in 0..<count where audioInputs[ch] != nil {
                        prod *= sampleInput(ch, i)
                    }
                    audioOutputs[0][i] = prod
                }
            } else if ainCount == 1 {
                let gain = in0
                for i in 0..<n {
                    audioOutputs[0][i] = sampleInput(0, i) * gain
                }
            }

        case .divide:
            if ainCount >= 2 {
                for i in 0..<n {
                    let num = sampleInput(0, i)
                    let den = sampleInput(1, i)
                    if abs(den) > 1e-6 {
                        let r = num / den
                        audioOutputs[0][i] = r.isFinite ? r : 0.0
                    } else {
                        audioOutputs[0][i] = 0.0
                    }
                }
            } else if ainCount == 1 {
                let den = in0
                if abs(den) > 1e-6 {
                    for i in 0..<n {
                        let r = sampleInput(0, i) / den
                        audioOutputs[0][i] = r.isFinite ? r : 0.0
                    }
                } else {
                    for i in 0..<n {
                        audioOutputs[0][i] = 0.0
                    }
                }
            }

        case .exp:
            if ainCount >= 1 {
                for i in 0..<n {
                    let x = max(-20.0, min(20.0, sampleInput(0, i)))
                    audioOutputs[0][i] = Float(Foundation.exp(Double(x)))
                }
            }

        case .audioOut:
            for i in 0..<n {
                let l = sampleInput(0, i)
                let r = sampleInput(1, i)
                audioOutputs[0][i] = max(-1.0, min(1.0, l))
                audioOutputs[1][i] = max(-1.0, min(1.0, r))
            }

        default:
            break
        }
    }
}

// MARK: - CPSAudioEngine

public final class CPSAudioEngine {
    public static let sampleRate: Double = 44100.0
    public static let blockSize: Int = 512

    public let wavCache: CPSWavCache
    public private(set) var patchDefinitions: [String: CPSPatchDefinition] = [:]

    // Active patch graph state
    public private(set) var nodesByID: [Int: CPSNode] = [:]
    public private(set) var orderedNodes: [CPSNode] = []
    public private(set) var sortedAudioNodes: [CPSNode] = []
    public private(set) var audioOutNode: CPSNode?
    public private(set) var globals: [String: Int] = [:]
    public private(set) var locals: [String: Int] = [:]
    public private(set) var isAudioRunning: Bool = false

    private var nextObjectID: Int = 1
    private var audioOrderDirty: Bool = true
    private let lock = NSRecursiveLock()

    // CoreAudio / AVAudioEngine real-time output
    private var avEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var residualLeft = [Float](repeating: 0.0, count: CPSAudioEngine.blockSize)
    private var residualRight = [Float](repeating: 0.0, count: CPSAudioEngine.blockSize)
    private var residualReadIndex: Int = CPSAudioEngine.blockSize

    public init(xtrasURL: URL, patchesJSONURL: URL? = nil) {
        self.wavCache = CPSWavCache(xtrasURL: xtrasURL)
        if let jsonURL = patchesJSONURL {
            try? loadPatchFile(at: jsonURL)
        }
    }

    // MARK: Patch JSON Loading & Execution

    public func loadPatchFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: CPSPatchDefinition].self, from: data)
        lock.lock()
        defer { lock.unlock() }
        for (key, value) in decoded {
            patchDefinitions[key] = value
        }
    }

    @discardableResult
    public func executePatch(named patchKey: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let patch = patchDefinitions[patchKey] else {
            return false
        }
        executeOperations(patch.ordered_operations)
        return true
    }

    public func executeOperations(_ operations: [CPSPatchOperation]) {
        lock.lock()
        defer { lock.unlock() }

        func resolveObjectID(_ token: String) -> Int? {
            if let localID = locals[token] {
                return localID
            }
            if let globalID = globals[token] {
                return globalID
            }
            if let literalID = Int(token) {
                return literalID
            }
            return nil
        }

        for op in operations {
            switch op.op {
            case "CPSxtra":
                if op.args?.first == "cleanAll" {
                    cleanAll()
                }

            case "CPSgetObject":
                guard let typeName = op.class ?? op.args?.first else { continue }
                let objID = createObject(typeName: typeName)
                if let assignName = op.var {
                    if op.scope == "global" {
                        globals[assignName] = objID
                    } else {
                        locals[assignName] = objID
                    }
                }

            case "CPSOBJConversate":
                let targetName = op.target ?? op.args?.first
                let msg = op.message ?? (op.args != nil && op.args!.count >= 2 ? op.args![1] : nil)
                guard let tName = targetName,
                      let command = msg,
                      let objID = resolveObjectID(tName) else { continue }
                conversate(objectID: objID, command: command)

            case "CPSgetConnection":
                if let srcName = op.src,
                   let srcPin = op.src_out_pin,
                   let dstName = op.dst,
                   let dstPin = op.dst_in_pin,
                   let srcID = resolveObjectID(srcName),
                   let dstID = resolveObjectID(dstName)
                {
                    connect(srcID: srcID, srcPin: srcPin, dstID: dstID, dstPin: dstPin)
                } else if let args = op.args, args.count >= 4,
                          let srcID = resolveObjectID(args[0]),
                          let srcPin = Int(args[1]),
                          let dstID = resolveObjectID(args[2]),
                          let dstPin = Int(args[3])
                {
                    connect(srcID: srcID, srcPin: srcPin, dstID: dstID, dstPin: dstPin)
                }

            case "CPSOBJkin":
                if let targetName = op.target,
                   let val = op.value?.floatValue,
                   let inlet = op.inlet,
                   let objID = resolveObjectID(targetName)
                {
                    kin(objectID: objID, value: val, inlet: inlet)
                } else if let args = op.args, args.count >= 3,
                          let objID = resolveObjectID(args[0]),
                          let val = Float(args[1]),
                          let inlet = Int(args[2])
                {
                    kin(objectID: objID, value: val, inlet: inlet)
                }

            case "CPSstartAudio":
                startAudio()

            case "CPSstopAudio":
                stopAudio()

            default:
                break
            }
        }
    }

    // MARK: Core CPS Xtra Operations

    public func cleanAll() {
        lock.lock()
        defer { lock.unlock() }
        isAudioRunning = false
        nodesByID.removeAll()
        orderedNodes.removeAll()
        sortedAudioNodes.removeAll()
        audioOutNode = nil
        globals.removeAll()
        locals.removeAll()
        nextObjectID = 1
        audioOrderDirty = true
        residualReadIndex = Self.blockSize
    }

    @discardableResult
    public func createObject(typeName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let kind = CPSNodeKind(rawValue: typeName) else {
            return 0
        }
        let id = nextObjectID
        nextObjectID += 1
        let node = CPSNode(id: id, kind: kind)
        nodesByID[id] = node
        orderedNodes.append(node)
        if kind == .audioOut {
            audioOutNode = node
        }
        audioOrderDirty = true
        return id
    }

    public func conversate(objectID: Int, command: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let node = nodesByID[objectID] else { return }
        node.conversate(command, wavCache: wavCache)
    }

    public func connect(srcID: Int, srcPin: Int, dstID: Int, dstPin: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard let srcNode = nodesByID[srcID],
              let dstNode = nodesByID[dstID] else { return }

        // Case 1: Control connection (srcPin 40..49 -> dstPin 20..29)
        if (40...49).contains(srcPin) && (20...29).contains(dstPin) {
            let outPin = srcPin - 40
            var inPin = dstPin - 20

            // Special case: table Pin 40 -> oscil Pin 20 passes wavetable reference immediately
            if srcNode.kind == .table && dstNode.kind == .oscil && outPin == 0 && inPin == 0 {
                dstNode.wavetableNode = srcNode
                return
            }

            // CPSDistr.exe 0x414171: Sort same-destination inPin descending in controlOuts[outPin]
            // so that when propagateControl traverses controlOuts[outPin] in reverse order,
            // lower inPins (cold operand pins 20, 21) are delivered BEFORE higher inPins (hot trigger pin 22).
            var list = srcNode.controlOuts[outPin]
            for i in 0..<list.count {
                if list[i].dstNode === dstNode && list[i].dstInPin < inPin {
                    let oldPin = list[i].dstInPin
                    list[i].dstInPin = inPin
                    inPin = oldPin
                }
            }
            list.append(CPSControlConnection(dstNode: dstNode, dstInPin: inPin))
            srcNode.controlOuts[outPin] = list
            return
        }

        // Case 2: Audio connection (srcPin 30..33 -> dstPin 10..17)
        if (30...33).contains(srcPin) && (10...17).contains(dstPin) {
            let outIdx = srcPin - 30
            let inIdx = dstPin - 10

            // Polymorphic '+', '*', '/', and 'exp' upgrade to audio rate when audio pins are connected
            if dstNode.kind == .plus || dstNode.kind == .multiply || dstNode.kind == .divide || dstNode.kind == .exp {
                if dstNode.aoutCount == 0 {
                    dstNode.aoutCount = 1
                }
                if inIdx + 1 > dstNode.ainCount {
                    dstNode.ainCount = inIdx + 1
                }
            }

            if outIdx < srcNode.audioOutputs.count && inIdx < dstNode.audioInputs.count {
                dstNode.audioInputs[inIdx] = (srcNode: srcNode, srcOutIndex: outIdx)
                audioOrderDirty = true
            }
        }
    }

    public func kin(objectID: Int, value: Float, inlet: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        guard let node = nodesByID[objectID] else { return }
        if node.kin(value: value, inPin: inlet) {
            propagateControl(from: node)
        }
    }

    public func kinGlobal(_ globalName: String, value: Float, inlet: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        guard let id = globals[globalName] else { return }
        kin(objectID: id, value: value, inlet: inlet)
    }

    public func node(forGlobal globalName: String) -> CPSNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let id = globals[globalName] else { return nil }
        return nodesByID[id]
    }

    public func node(forLocal localName: String) -> CPSNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let id = locals[localName] else { return nil }
        return nodesByID[id]
    }

    /// Configures `cScore1`..`cScore7` in `score_cps_graph` using the exact Dutch spoken-score rules from `score.dxr` Cast #2.
    public func configureScoreReadout(totalScore: Int, triggerImmediately: Bool = true) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = max(0, totalScore)
        var gDuizend = clamped / 1000
        var gHonderd = (clamped % 1000) / 100
        if clamped >= 1000 && clamped < 2000 {
            gDuizend = 0
            gHonderd = clamped / 100
        }

        // Slot 68: "u heeft" (score\eve51.hrs)
        kinGlobal("cScore1", value: 68.0, inlet: 0)

        if gDuizend > 65 {
            // Slot 72: "te veel" (score\cijfteveel.hrs)
            kinGlobal("cScore2", value: 72.0, inlet: 0)
        } else {
            kinGlobal("cScore2", value: Float(gDuizend), inlet: 0)
        }

        if gDuizend > 0 {
            // Slot 67: "duizend" (score\cijf1000.hrs)
            kinGlobal("cScore3", value: 67.0, inlet: 0)
        } else {
            kinGlobal("cScore3", value: 0.0, inlet: 0)
        }

        if gHonderd == 1 && gDuizend != 1 {
            kinGlobal("cScore4", value: 0.0, inlet: 0)
        } else {
            kinGlobal("cScore4", value: Float(gHonderd), inlet: 0)
        }

        if gHonderd > 0 {
            // Slot 66: "honderd" (score\cijf100.hrs)
            kinGlobal("cScore5", value: 66.0, inlet: 0)
        } else {
            kinGlobal("cScore5", value: 0.0, inlet: 0)
        }

        if gDuizend == 0 && gHonderd == 0 {
            // Slot 71: "nul" (score\cijf0.hrs)
            kinGlobal("cScore4", value: 71.0, inlet: 0)
        }

        // Slot 69: "punten behaald" (score\eve52.hrs)
        kinGlobal("cScore6", value: 69.0, inlet: 0)
        kinGlobal("cScore7", value: 0.0, inlet: 0)

        if triggerImmediately {
            kinGlobal("cStartscore", value: 1.0, inlet: 0)
        }
    }

    // MARK: Control Graph Propagation (Exact CPSDistr.exe 0x4102d0 Semantics)

    private func propagateControl(from srcNode: CPSNode) {
        let maxOut = min(srcNode.koutCount, srcNode.controlOuts.count)
        guard maxOut > 0 else { return }

        for outPin in 0..<maxOut {
            guard let outVal = srcNode.kout(outPin: outPin) else { continue }
            let connections = srcNode.controlOuts[outPin]
            guard !connections.isEmpty else { continue }

            // CPSDistr.exe 0x41035d: Traverse connections in reverse order (count - 1 down to 0)
            var idx = connections.count - 1
            while idx >= 0 {
                let conn = connections[idx]
                let dst = conn.dstNode
                if dst.recursionDepth < 2 {
                    dst.recursionDepth += 1
                    let shouldPropagate = dst.kin(value: outVal, inPin: conn.dstInPin)
                    if shouldPropagate {
                        propagateControl(from: dst)
                    }
                    dst.recursionDepth -= 1
                }
                idx -= 1
            }
        }
    }

    // MARK: Audio Topological Sort & Block Rendering

    private func rebuildAudioOrderIfNeeded() {
        guard audioOrderDirty else { return }
        audioOrderDirty = false

        var visited = Set<Int>()
        var sorted: [CPSNode] = []

        func visit(_ node: CPSNode) {
            guard !visited.contains(node.id) else { return }
            visited.insert(node.id)
            for input in node.audioInputs {
                if let src = input?.srcNode {
                    visit(src)
                }
            }
            if node.isAudioNode {
                sorted.append(node)
            }
        }

        // First visit everything reachable from audioOut
        if let out = audioOutNode {
            visit(out)
        }
        // Also visit any other audio nodes (such as audioFromDisk nodes with control outputs)
        for node in orderedNodes where node.isAudioNode {
            visit(node)
        }

        sortedAudioNodes = sorted
    }

    /// Renders a single 512-sample block at 44,100 Hz and returns the stereo buffers.
    @discardableResult
    public func renderBlock() -> (left: [Float], right: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        rebuildAudioOrderIfNeeded()

        for node in sortedAudioNodes {
            node.performBlock()
            // CPSDistr.exe 0x40ea84: audioFromDisk emits samplesPlayed on Pin 40 after each block
            if node.kind == .audioFromDisk && node.koutCount > 0 && !node.controlOuts[0].isEmpty {
                propagateControl(from: node)
            }
        }

        if let out = audioOutNode {
            return (left: out.audioOutputs[0], right: out.audioOutputs[1])
        } else {
            let zero = [Float](repeating: 0.0, count: Self.blockSize)
            return (left: zero, right: zero)
        }
    }

    /// Renders `count` 512-sample blocks offline and returns concatenated stereo buffers.
    public func renderBlocks(_ count: Int) -> (left: [Float], right: [Float]) {
        guard count > 0 else { return ([], []) }
        var allLeft: [Float] = []
        var allRight: [Float] = []
        allLeft.reserveCapacity(count * Self.blockSize)
        allRight.reserveCapacity(count * Self.blockSize)

        for _ in 0..<count {
            let (l, r) = renderBlock()
            allLeft.append(contentsOf: l)
            allRight.append(contentsOf: r)
        }
        return (allLeft, allRight)
    }

    /// Advances the engine by `count` blocks and returns peak and RMS statistics.
    public func processBlocks(_ count: Int) -> (peakLeft: Float, peakRight: Float, rmsLeft: Float, rmsRight: Float) {
        guard count > 0 else { return (0, 0, 0, 0) }
        var peakL: Float = 0.0
        var peakR: Float = 0.0
        var sumSqL: Double = 0.0
        var sumSqR: Double = 0.0
        let totalSamples = Double(count * Self.blockSize)

        for _ in 0..<count {
            let (l, r) = renderBlock()
            for i in 0..<Self.blockSize {
                let sl = l[i]
                let sr = r[i]
                let al = abs(sl)
                let ar = abs(sr)
                if al > peakL { peakL = al }
                if ar > peakR { peakR = ar }
                sumSqL += Double(sl * sl)
                sumSqR += Double(sr * sr)
            }
        }

        let rmsL = Float(Foundation.sqrt(sumSqL / totalSamples))
        let rmsR = Float(Foundation.sqrt(sumSqR / totalSamples))
        return (peakL, peakR, rmsL, rmsR)
    }

    // MARK: Real-Time AVAudioEngine Lifecycle

    public func startAudio(enableHardwareOutput: Bool = false) {
        lock.lock()
        isAudioRunning = true
        lock.unlock()

        if enableHardwareOutput {
            startHardwareAudioIfNeeded()
        }
    }

    public func stopAudio() {
        lock.lock()
        isAudioRunning = false
        lock.unlock()
    }

    public func startHardwareAudioIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        if let engine = avEngine, engine.isRunning {
            return
        }

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        ) else {
            return
        }

        let srcNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            self.lock.lock()
            defer { self.lock.unlock() }

            guard self.isAudioRunning else {
                for buf in abl {
                    if let ptr = buf.mData {
                        memset(ptr, 0, Int(buf.mDataByteSize))
                    }
                }
                return noErr
            }

            if abl.count >= 2 {
                guard let outL = abl[0].mData?.assumingMemoryBound(to: Float.self),
                      let outR = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                    return noErr
                }
                var written = 0
                while written < frames {
                    if self.residualReadIndex >= Self.blockSize {
                        let (blkL, blkR) = self.renderBlock()
                        self.residualLeft = blkL
                        self.residualRight = blkR
                        self.residualReadIndex = 0
                    }
                    let avail = Self.blockSize - self.residualReadIndex
                    let toCopy = min(avail, frames - written)
                    for i in 0..<toCopy {
                        outL[written + i] = self.residualLeft[self.residualReadIndex + i]
                        outR[written + i] = self.residualRight[self.residualReadIndex + i]
                    }
                    self.residualReadIndex += toCopy
                    written += toCopy
                }
            } else if abl.count == 1 {
                guard let outInterleaved = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                    return noErr
                }
                var written = 0
                while written < frames {
                    if self.residualReadIndex >= Self.blockSize {
                        let (blkL, blkR) = self.renderBlock()
                        self.residualLeft = blkL
                        self.residualRight = blkR
                        self.residualReadIndex = 0
                    }
                    let avail = Self.blockSize - self.residualReadIndex
                    let toCopy = min(avail, frames - written)
                    for i in 0..<toCopy {
                        outInterleaved[(written + i) * 2] = self.residualLeft[self.residualReadIndex + i]
                        outInterleaved[(written + i) * 2 + 1] = self.residualRight[self.residualReadIndex + i]
                    }
                    self.residualReadIndex += toCopy
                    written += toCopy
                }
            }

            return noErr
        }

        engine.attach(srcNode)
        engine.connect(srcNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            self.avEngine = engine
            self.sourceNode = srcNode
        } catch {
            // Headless / CI machines without audio output device fall back gracefully
        }
    }

    public func stopHardwareAudio() {
        lock.lock()
        defer { lock.unlock() }
        avEngine?.stop()
        avEngine = nil
        sourceNode = nil
    }
}
