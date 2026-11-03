import Foundation

// MARK: - Director Key Codes & Movie Types

public enum DirectorKeyCode {
    public static let returnKey: UInt16 = 36
    public static let space: UInt16 = 49
    public static let backspace: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let left: UInt16 = 123
    public static let right: UInt16 = 124
    public static let down: UInt16 = 125
    public static let up: UInt16 = 126
}

public enum DirectorMovieType: String, CaseIterable {
    case intro = "intro.dir"
    case menu = "menu.dir"
    case game = "game.dir"
    case score = "score.dir"
    case quit = "quit.dir"

    /// Exact DRCF frame tempo (FPS) extracted from the original .dxr files.
    public var frameRate: Int {
        switch self {
        case .intro, .menu, .score, .quit:
            return 30
        case .game:
            return 12
        }
    }

    /// Number of 60 Hz Director timer ticks (`the timer`) per movie frame.
    public var ticksPerFrame: Int {
        return 60 / frameRate
    }

    /// Stage background image relative to the `pics` directory.
    public var stageImageName: String {
        switch self {
        case .intro, .menu, .game, .score:
            return "cover6.jpg"
        case .quit:
            return "cdsplash.jpg"
        }
    }
}

// MARK: - High Score & sdata Persistence

public struct HighScoreRecord: Codable, Equatable {
    public var score: Int
    public var name: String

    public static let defaultRecord = HighScoreRecord(score: 53700, name: "sander")

    public init(score: Int, name: String) {
        self.score = score
        self.name = name
    }
}

public final class HighScoreStore {
    public let xtrasURL: URL

    public var sdataURL: URL {
        xtrasURL.appendingPathComponent("sdata")
    }

    public var hiscoreJSONURL: URL {
        xtrasURL.appendingPathComponent("hiscore.json")
    }

    public init(xtrasURL: URL) {
        self.xtrasURL = xtrasURL
        ensureDefaultHighScoreExists()
    }

    public func ensureDefaultHighScoreExists() {
        if !FileManager.default.fileExists(atPath: hiscoreJSONURL.path) {
            saveHighScore(.defaultRecord)
        }
    }

    public func loadHighScore() -> HighScoreRecord {
        guard let data = try? Data(contentsOf: hiscoreJSONURL),
              let record = try? JSONDecoder().decode(HighScoreRecord.self, from: data) else {
            let def = HighScoreRecord.defaultRecord
            saveHighScore(def)
            return def
        }
        return record
    }

    public func saveHighScore(_ record: HighScoreRecord) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(record) {
            try? data.write(to: hiscoreJSONURL, options: .atomic)
        }
    }

    public func writeSData(_ text: String) {
        try? text.write(to: sdataURL, atomically: true, encoding: .utf8)
    }

    public func readSData() -> String? {
        guard let raw = try? String(contentsOf: sdataURL, encoding: .utf8) else {
            return nil
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Movie State Containers

public struct MenuMovieState {
    public var menuCounter: Int = 0
    public var gTemp: Int = 0
    public var `var`: Int = 0
    public var musicFade1: Float = 0.7

    public init() {}
}

public struct GameMovieState {
    // All globals from game.dxr Script #28 (Chunk 186)
    public var gStartStil: Int = 0
    public var gStaStil: Int = 0
    public var gStartGa: Int = 0
    public var gConSpeed99: Int = 0
    public var gConSpeed199: Int = 0
    public var gConSpeed299: Int = 0
    public var gConSpeed399: Int = 0
    public var gConSpeed499: Int = 0
    public var gConSpeed599: Int = 0
    public var gConSpeed699: Int = 0
    public var gConSpeed799: Int = 0
    public var gTwinCheck: Float = 0.0
    public var gCurSpeed: Float = 0.0
    public var gOldSpeed: Float = 0.0
    public var gBijSpeedUp: Int = 0
    public var gTussenteller: Int = 0
    public var gBackgroundindex: Float = 1.0
    public var gBackVolume: Float = 0.0
    public var gEvAfstand: Int = 0
    public var gEvVolume: Float = 0.0
    public var gIndextemp: Int = 0
    public var gAccel: Float = 2.0
    public var gSpeed: Float = 0.0
    public var gSpeedMax: Float = 99.0
    public var gStroop: Float = 3.0
    public var gRem: Float = 30.0
    public var gKeyLock: Int = 0
    public var gCapLock: Int = 0
    public var gAfstand: Float = 0.0
    public var gAfstandtemp1: Float = 0.0
    public var gAfstandtemp2: Float = 2.0
    public var gMeter: Float = 0.01
    public var gCounter: Float = 0.0
    public var gInterval: Float = 12.0
    public var gBoAfstand: Float = 100.0
    public var gBoVolume: Float = 0.0
    public var gBoReady: Int = 0
    public var gBoAmount: Int = 0
    public var gBoBusy: Int = 0
    public var gBoTimer: Int = 0
    public var gBoCapTimer: Int = 0
    public var gBoBaan: Int = 0
    public var gSWAfstand: Float = 500.0
    public var gSWVolume: Float = 0.0
    public var gSWReady: Int = 0
    public var gSWAmount: Int = 0
    public var gSWBusy: Int = 0
    public var gReady: Int = 0
    public var gMusicVolume: Float = 0.9
    public var gMusiclevel: Float = 1.0
    public var gMusicIndex: Float = 1.0
    public var gBreakStop: Int = 0
    public var gBreakTimer: Int = 0
    public var gScore: Int = 0
    public var gTimeAder: Int = 0
    public var gTAtemp1: Int = 0
    public var gRemIn: Int = 0
    public var gSick: Float = 23.0
    public var gKotsRuler: Int = 0
    public var gKotsteller: Int = 0
    public var gCapLockTime: Int = 0
    public var gEndLockTime: Int = 0
    public var gEndLock: Int = 0
    public var gBoosterhehe: Int = 0
    public var gStemteller: Float = 0.0

    // Cast Member STXT Fields in game.dxr
    public var gSpeedField: String = "125.0000"
    public var gAfstandField: String = "3304.0900"
    public var gCounterField: String = "0.0000"
    public var gBoAfstandField: String = "100.0000"
    public var gBoVolumeField: String = "0.0000"
    public var gSWAfstandField: String = "500.0000"
    public var gSWVolumeField: String = "0.0000"
    public var gBoTimerField: String = "71"
    public var gBoAmountField: String = "0"
    public var gSpeedMaxField: String = "299.0000"
    public var gCapLockField: String = "0"
    public var gTimeAderField: String = "1235"
    public var gMusicIndexField: String = "12.0000"
    public var gMusiclevelField: String = "11.0000"
    public var gMusicVolumeField: String = "0.9000"
    public var gBackVolumeField: String = "0.3750"
    public var gEvAfstandField: String = "100.0000"
    public var gEvVolumeField: String = "0.0000"
    public var gScoreField: String = "0"

    public init() {}

    public mutating func syncFields() {
        gSpeedField = String(format: "%.4f", gSpeed)
        gAfstandField = String(format: "%.4f", gAfstand)
        gCounterField = String(format: "%.4f", gCounter)
        gBoAfstandField = String(format: "%.4f", gBoAfstand)
        gBoVolumeField = String(format: "%.4f", gBoVolume)
        gSWAfstandField = String(format: "%.4f", gSWAfstand)
        gSWVolumeField = String(format: "%.4f", gSWVolume)
        gBoTimerField = "\(gBoTimer)"
        gBoAmountField = "\(gBoAmount)"
        gSpeedMaxField = String(format: "%.4f", gSpeedMax)
        gCapLockField = "\(gCapLock)"
        gTimeAderField = "\(gTimeAder)"
        gMusicIndexField = String(format: "%.4f", gMusicIndex)
        gMusiclevelField = String(format: "%.4f", gMusiclevel)
        gMusicVolumeField = String(format: "%.4f", gMusicVolume)
        gBackVolumeField = String(format: "%.4f", gBackVolume)
        gEvAfstandField = String(format: "%.4f", Float(gEvAfstand))
        gEvVolumeField = String(format: "%.4f", gEvVolume)
    }

    public var currentGear: Int {
        if gSpeed <= 99 { return 1 }
        if gSpeed <= 199 { return 2 }
        if gSpeed <= 299 { return 3 }
        if gSpeed <= 399 { return 4 }
        return 5
    }
}

public struct ScoreMovieState {
    // Globals from score.dxr
    public var gCharNum: Int = 0
    public var gKnoppie: Int = 0
    public var gInvoer: Int = 0
    public var gInvoerSet: Int = 0
    public var musicFade1: Float = 1.0
    public var gFlag: Int = 0
    public var gTimer: Int = 0
    public var gDuizend: Float = 0.0
    public var gHonderd: Float = 0.0
    public var lScore: Int = 0
    public var lHiScore: Int = 53700
    public var gNetTeller: Int = 0

    // STXT Fields from score.dxr
    public var numberField: String = "4"
    public var gScoreField2: String = "8100"
    public var gScoreField3: String = "53700"
    public var gUrlField: String = "http://www2.hku.nl/~audiogam/drive/score2/dirscore.php3"
    public var gUrlField2: String = "http://www2.hku.nl/~audiogam/drive/score2/score.php3?score="
    public var gNameField: String = "r"
    public var gNameField2: String = "sander"
    public var gUrlField3: String = "http://www2.hku.nl/~audiogam/drive/score2/name.php3?name="

    public init() {}
}

// MARK: - DirectorRuntime

public final class DirectorRuntime {
    public let audioEngine: CPSAudioEngine
    public let highScoreStore: HighScoreStore
    public let xtrasURL: URL
    public let picsURL: URL

    // Playback head & timing state
    public private(set) var currentMovie: DirectorMovieType = .intro
    public private(set) var currentFrame: Int = 1
    private var pendingFrame: Int?
    private var pendingMovie: (movie: DirectorMovieType, frame: Int)?

    /// Director's `the timer` (ticks at 60 Hz, reset via `startTimer()` or `the timer = 0`).
    public var theTimer: Int = 0
    private var frameTickAccumulator: Int = 0

    /// True when `quit()` has been executed in `quit.dxr`.
    public private(set) var didQuit: Bool = false

    // Keyboard state
    public private(set) var keysDown: Set<UInt16> = []
    private var latchedKeysDown: Set<UInt16> = []
    public private(set) var lastKey: String = ""
    public private(set) var lastKeyCode: UInt16 = 0

    // Deterministic RNG option for testing (`nil` uses system random)
    public var customRandomGenerator: ((Int) -> Int)?

    // Movie states
    public var menuState = MenuMovieState()
    public var gameState = GameMovieState()
    public var scoreState = ScoreMovieState()

    public init(audioEngine: CPSAudioEngine, xtrasURL: URL, picsURL: URL) {
        self.audioEngine = audioEngine
        self.xtrasURL = xtrasURL
        self.picsURL = picsURL
        self.highScoreStore = HighScoreStore(xtrasURL: xtrasURL)
        loadMovie(.intro, frame: 1)
    }

    // MARK: - Director Built-ins

    /// Evaluates `the frame` in Lingo (reflecting any `go(X)` already issued in the current handler).
    public var theFrame: Int {
        return pendingFrame ?? currentFrame
    }

    public func startTimer() {
        theTimer = 0
    }

    public func go(_ frame: Int) {
        pendingFrame = frame
    }

    public func go(_ frame: Int, movie rawMovieName: String) {
        let lower = rawMovieName.lowercased()
        let target: DirectorMovieType
        if lower.contains("intro") {
            target = .intro
        } else if lower.contains("menu") {
            target = .menu
        } else if lower.contains("game") {
            target = .game
        } else if lower.contains("score") {
            target = .score
        } else if lower.contains("quit") {
            target = .quit
        } else {
            target = .menu
        }
        pendingMovie = (movie: target, frame: frame)
    }

    /// Director `random(N)` returns an integer in `1...N`.
    public func lingoRandom(_ maxVal: Int) -> Int {
        guard maxVal > 1 else { return 1 }
        if let custom = customRandomGenerator {
            return max(1, min(maxVal, custom(maxVal)))
        }
        return Int.random(in: 1...maxVal)
    }

    public func keyPressed(_ keyCode: UInt16) -> Bool {
        return keysDown.contains(keyCode) || latchedKeysDown.contains(keyCode)
    }

    // MARK: - Movie Lifecycle & Frame Stepping

    public func loadMovie(_ movie: DirectorMovieType, frame: Int = 1) {
        currentMovie = movie
        currentFrame = frame
        pendingFrame = nil
        pendingMovie = nil
        frameTickAccumulator = 0
        keysDown.removeAll()
        latchedKeysDown.removeAll()

        runStartMovie(for: movie)
        runEnterFrameAndFollowRedirects()
    }

    /// Advances the 60 Hz Director clock by 1 tick (`1/60` second) and executes a frame step when due.
    public func stepTick() {
        guard !didQuit else { return }
        theTimer += 1
        frameTickAccumulator += 1
        if frameTickAccumulator >= currentMovie.ticksPerFrame {
            frameTickAccumulator = 0
            stepSingleFrame()
        }
    }

    /// Advances one full Director frame at the current movie's tempo, incrementing `theTimer` by `ticksPerFrame`.
    public func stepFrame() {
        guard !didQuit else { return }
        theTimer += currentMovie.ticksPerFrame
        frameTickAccumulator = 0
        stepSingleFrame()
    }

    private func stepSingleFrame() {
        guard !didQuit else { return }
        pendingFrame = nil
        pendingMovie = nil

        runExitFrame(for: currentMovie, frame: currentFrame)
        latchedKeysDown.removeAll()

        if didQuit {
            return
        }

        if let movieTransition = pendingMovie {
            runStopMovie(for: currentMovie)
            loadMovie(movieTransition.movie, frame: movieTransition.frame)
            return
        }

        let previousFrame = currentFrame
        if let targetFrame = pendingFrame {
            currentFrame = targetFrame
        } else {
            currentFrame += 1
        }
        pendingFrame = nil

        // In Director, enterFrame runs when entering a new frame (or when looping if the frame has enterFrame).
        if currentFrame != previousFrame {
            runEnterFrameAndFollowRedirects()
        }
    }

    private func runEnterFrameAndFollowRedirects() {
        var safety = 0
        while safety < 8 && !didQuit {
            safety += 1
            pendingFrame = nil
            pendingMovie = nil
            runEnterFrame(for: currentMovie, frame: currentFrame)
            if let movieTransition = pendingMovie {
                runStopMovie(for: currentMovie)
                loadMovie(movieTransition.movie, frame: movieTransition.frame)
                return
            }
            if let next = pendingFrame, next != currentFrame {
                currentFrame = next
                pendingFrame = nil
                continue
            }
            break
        }
    }

    // MARK: - Keyboard Event Dispatch

    public func handleKeyDown(keyCode: UInt16, characters: String = "") {
        guard !didQuit else { return }
        keysDown.insert(keyCode)
        latchedKeysDown.insert(keyCode)
        lastKeyCode = keyCode
        if !characters.isEmpty {
            lastKey = characters
        } else if keyCode == DirectorKeyCode.space {
            lastKey = " "
        } else if keyCode == DirectorKeyCode.returnKey {
            lastKey = "\r"
        } else {
            lastKey = ""
        }

        pendingFrame = nil
        pendingMovie = nil

        switch currentMovie {
        case .intro:
            introKeyDown(keyCode: keyCode, key: lastKey)
        case .menu:
            menuKeyDown(keyCode: keyCode, key: lastKey)
        case .game:
            gameKeyDown(keyCode: keyCode, key: lastKey)
        case .score:
            scoreKeyDown(keyCode: keyCode, key: lastKey)
        case .quit:
            quitKeyDown(keyCode: keyCode, key: lastKey)
        }

        applyImmediateNavigationIfNeeded()
    }

    public func handleKeyUp(keyCode: UInt16, characters: String = "") {
        keysDown.remove(keyCode)
        guard !didQuit else { return }
        lastKeyCode = keyCode
        if !characters.isEmpty {
            lastKey = characters
        }

        pendingFrame = nil
        pendingMovie = nil

        if currentMovie == .game {
            gameKeyUp(keyCode: keyCode)
        }

        applyImmediateNavigationIfNeeded()
    }

    private func applyImmediateNavigationIfNeeded() {
        if let movieTransition = pendingMovie {
            runStopMovie(for: currentMovie)
            loadMovie(movieTransition.movie, frame: movieTransition.frame)
            return
        }
        if let targetFrame = pendingFrame, targetFrame != currentFrame {
            currentFrame = targetFrame
            pendingFrame = nil
            runEnterFrameAndFollowRedirects()
        }
    }

    // MARK: - Movie Dispatchers

    private func runStartMovie(for movie: DirectorMovieType) {
        switch movie {
        case .intro:
            break
        case .menu:
            // menu.dxr Script #3: on startMovie()
            menuState = MenuMovieState()
            menuState.menuCounter = 0
        case .game:
            // game.dxr Script #28: on startMovie()
            gameStartMovie()
        case .score:
            // score.dxr Script #1: on startMovie()
            scoreStartMovie()
        case .quit:
            break
        }
    }

    private func runStopMovie(for movie: DirectorMovieType) {
        // All 5 movies have on stopMovie() -> CPSstopAudio()
        audioEngine.stopAudio()
    }

    private func runEnterFrame(for movie: DirectorMovieType, frame: Int) {
        switch movie {
        case .intro:
            if frame == 5 {
                // intro.dxr Script #9 (Frame 5)
                audioEngine.kinGlobal("cTriggermusic", value: 1.0, inlet: 1)
                audioEngine.kinGlobal("cVolumemusic", value: 0.8, inlet: 0)
                startTimer()
            }
        case .menu:
            if frame == 4 {
                // menu.dxr Script #10 (Frame 4)
                audioEngine.kinGlobal("cTriggermusic", value: 1.0, inlet: 1)
            } else if frame == 10 {
                // menu.dxr Script #26 (Frame 10)
                audioEngine.kinGlobal("cTriggersampler2", value: 3.0, inlet: 1)
                audioEngine.kinGlobal("cTriggersampler1", value: 1.0, inlet: 1)
                go(11)
            }
        case .game:
            // game.dxr Script #27 (Frame 1): cursor(200)
            break
        case .score:
            // score.dxr Script #29 (Frame 68) & Script #38 (Frame 75) log messages on enterFrame
            break
        case .quit:
            if frame == 5 {
                // quit.dxr Script #9 (Frame 5)
                audioEngine.kinGlobal("cTriggermusic", value: 1.0, inlet: 1)
                audioEngine.kinGlobal("cVolumemusic", value: 0.8, inlet: 0)
                startTimer()
            }
        }
    }

    private func runExitFrame(for movie: DirectorMovieType, frame: Int) {
        switch movie {
        case .intro:
            introExitFrame(frame)
        case .menu:
            menuExitFrame(frame)
        case .game:
            gameExitFrame(frame)
        case .score:
            scoreExitFrame(frame)
        case .quit:
            quitExitFrame(frame)
        }
    }

    // MARK: - 1. INTRO MOVIE (intro.dxr)

    private func introExitFrame(_ frame: Int) {
        switch frame {
        case 2:
            // Script #22 (Chunk 267)
            audioEngine.executePatch(named: "intro_cps")
        case 9:
            // Script #3 (Chunk 264)
            if theTimer < 60 * 36 {
                go(theFrame)
            } else {
                audioEngine.kinGlobal("cVolumemusic", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cTriggermusic", value: 0.0, inlet: 1)
                audioEngine.stopAudio()
                go(1, movie: "menu.dir")
            }
        default:
            break
        }
    }

    private func introKeyDown(keyCode: UInt16, key: String) {
        guard currentFrame == 9 else { return }
        if key == " " || keyCode == DirectorKeyCode.space {
            audioEngine.kinGlobal("cVolumemusic", value: 0.0, inlet: 0)
            audioEngine.kinGlobal("cTriggermusic", value: 0.0, inlet: 1)
            audioEngine.stopAudio()
            go(1, movie: "menu.dir")
        }
    }

    // MARK: - 2. MENU MOVIE (menu.dxr)

    private func menuomlaag() {
        menuState.menuCounter += 1
        if menuState.menuCounter > 4 {
            menuState.menuCounter = 1
        }
    }

    private func menuomhoog() {
        menuState.menuCounter -= 1
        if menuState.menuCounter < 1 {
            menuState.menuCounter = 4
        }
    }

    private func menutext() {
        switch menuState.menuCounter {
        case 1: go(50)
        case 2: go(60)
        case 3: go(70)
        case 4: go(80)
        default: break
        }
    }

    private func checkding() {
        switch menuState.menuCounter {
        case 1: audioEngine.kinGlobal("cTriggersampler1", value: 3.0, inlet: 1)
        case 2: audioEngine.kinGlobal("cTriggersampler1", value: 4.0, inlet: 1)
        case 3: audioEngine.kinGlobal("cTriggersampler1", value: 5.0, inlet: 1)
        case 4: audioEngine.kinGlobal("cTriggersampler1", value: 6.0, inlet: 1)
        default: break
        }
    }

    private func enterding() {
        if keyPressed(DirectorKeyCode.returnKey) {
            audioEngine.kinGlobal("cTriggersampler2", value: 2.0, inlet: 1)
            menutext()
        }
    }

    private func menuExitFrame(_ frame: Int) {
        switch frame {
        case 2:
            // Script #17 ('CPS')
            audioEngine.executePatch(named: "menu_cps")
        case 11:
            // Script #12 ('NavInfo Evelien Timer part1')
            menuState.gTemp = 0
            startTimer()
        case 12:
            // Script #36
            menuState.var = 0
        case 13:
            // Script #1 ('Menu LOOP')
            menuState.gTemp += 1
            if menuState.gTemp > 400 {
                go(10)
            }
            enterding()
            go(theFrame)
        case 50:
            // Script #27 ('Start SPELEN')
            audioEngine.kinGlobal("cTriggersampler1", value: 7.0, inlet: 1)
            startTimer()
        case 51:
            // Script #28 ('Timer SPELEN en go MOVIE')
            if theTimer < 60 * 4 {
                go(theFrame)
            } else {
                menuState.musicFade1 = 0.7
                go(100)
            }
        case 60:
            // Script #29 ('Start INFO')
            audioEngine.kinGlobal("cTriggersampler1", value: 8.0, inlet: 1)
            startTimer()
        case 61:
            // Script #30 ('Loop INFO')
            if theTimer < 60 * 31 {
                go(theFrame)
            } else {
                go(10)
            }
        case 70:
            // Script #31 ('Start TRAINING')
            audioEngine.kinGlobal("cTriggersampler1", value: 9.0, inlet: 1)
            startTimer()
        case 71:
            // Script #32 ('Loop TRAINING')
            if theTimer < 60 * 43 {
                go(theFrame)
            } else {
                go(10)
            }
        case 80:
            // Script #34 ('Start QUIT')
            audioEngine.kinGlobal("cTriggersampler1", value: 10.0, inlet: 1)
            startTimer()
        case 81:
            // Script #35 ('loop QUIT')
            if theTimer < 60 * 43 {
                go(theFrame)
            } else {
                go(80)
            }
        case 85:
            // Script #25 ('startQuitEND')
            audioEngine.kinGlobal("cTriggersampler1", value: 11.0, inlet: 1)
            startTimer()
        case 86:
            // Script #24 ('loop QuitEND')
            if theTimer < 60 * 4 {
                go(theFrame)
            } else {
                menuState.musicFade1 = 0.7
                go(110)
            }
        case 100:
            // Script #33 ('fade muziek' -> game.dir)
            audioEngine.kinGlobal("cTriggersampler1", value: 0.0, inlet: 1)
            if menuState.musicFade1 > 0.0 {
                menuState.musicFade1 -= 0.01
                audioEngine.kinGlobal("cVolumemusic", value: max(0.0, menuState.musicFade1), inlet: 0)
                go(theFrame)
            } else {
                audioEngine.kinGlobal("cTriggermusic", value: 0.0, inlet: 1)
                audioEngine.stopAudio()
                go(1, movie: "game.dir")
            }
        case 110:
            // Script #23 ('fade muziek' -> quit.dir)
            audioEngine.kinGlobal("cTriggersampler1", value: 0.0, inlet: 1)
            if menuState.musicFade1 > 0.0 {
                menuState.musicFade1 -= 0.01
                audioEngine.kinGlobal("cVolumemusic", value: max(0.0, menuState.musicFade1), inlet: 0)
                go(theFrame)
            } else {
                audioEngine.kinGlobal("cTriggermusic", value: 0.0, inlet: 1)
                audioEngine.stopAudio()
                go(1, movie: "quit.dir")
            }
        default:
            break
        }
    }

    private func menuKeyDown(keyCode: UInt16, key: String) {
        switch currentFrame {
        case 13:
            // Script #1 ('Menu LOOP')
            menuState.gTemp = 0
            if keyCode == DirectorKeyCode.down {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                menuomlaag()
                checkding()
                startTimer()
            }
            if keyCode == DirectorKeyCode.up {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                if menuState.var == 1 {
                    menuomhoog()
                } else {
                    menuomlaag()
                    menuState.var = 1
                }
                checkding()
                startTimer()
            }
            if keyCode == DirectorKeyCode.right {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                menuomlaag()
                checkding()
                startTimer()
            }
            if keyCode == DirectorKeyCode.left {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                if menuState.var == 1 {
                    menuomhoog()
                } else {
                    menuomlaag()
                    menuState.var = 1
                }
                checkding()
                startTimer()
            }
        case 61, 71:
            // Script #30 ('Loop INFO') & Script #32 ('Loop TRAINING')
            if key == " " || keyCode == DirectorKeyCode.space {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                audioEngine.kinGlobal("cTriggersampler1", value: 0.0, inlet: 1)
                menuState.menuCounter = 0
                go(10)
            }
        case 81:
            // Script #35 ('loop QUIT')
            if keyCode == DirectorKeyCode.returnKey {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                go(85)
            } else {
                audioEngine.kinGlobal("cTriggersampler2", value: 1.0, inlet: 1)
                menuState.menuCounter = 0
                go(10)
            }
        default:
            break
        }
    }

    // MARK: - 3. GAME MOVIE (game.dxr)

    private func gameStartMovie() {
        gameState = GameMovieState()
        gameState.syncFields()
    }

    private func gameExitFrame(_ frame: Int) {
        switch frame {
        case 5:
            // Script #7 ('CPS')
            audioEngine.executePatch(named: "game_cps_graph")
        case 7:
            // Script #8 ('Init')
            audioEngine.executePatch(named: "game_cps_init")
            theTimer = 0
        case 9:
            // Script #13 ('StartAudio!!!')
            go(39)
        case 10:
            // Script #0 ('FreeDrive 100')
            gameKeyCheck()
            gameInterCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameCapLock()
            gameEndCheck()
            gameTimeAder()
            gameBreakStop()
            gameKotsRuler()
            go(theFrame)
        case 20:
            // Script #1 ('BoAanloop')
            gameState.gBoReady = 0
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameBoAanloop()
            gameCapLock()
            gameEndCheck()
            gameTimeAder()
            gameBreakStop()
            go(theFrame)
        case 21:
            // Script #3 ('BoInside')
            gameState.gBoReady = 1
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameBoInside()
            gameCapLock()
            gameEndCheck()
            gameTimeAder()
            gameBreakStop()
            go(theFrame)
        case 22:
            // Script #4 ('BoAfloop')
            gameState.gBoReady = 0
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameBoAfloop()
            gameCapLock()
            gameEndCheck()
            gameTimeAder()
            gameBreakStop()
            go(theFrame)
        case 25:
            // Script #12 ('EventAanloop')
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameCapLock()
            gameEndCheck()
            gameTimeAder()
            gameState.gEvAfstand += 1
            if gameState.gEvAfstand <= 75 {
                go(theFrame)
            } else {
                gameState.gEvAfstand = 0
                go(10)
            }
        case 30:
            // Script #2 ('SWAanloop')
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameSWAanloop()
            go(theFrame)
        case 31:
            // Script #5 ('SWInside')
            gameState.gSWReady = 1
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameBoInside()
            go(theFrame)
        case 32:
            // Script #6 ('SWAfloop')
            gameState.gReady = 0
            gameKeyCheck()
            gameShiftCheck()
            gameShiftDwn()
            gameBoAfloop()
            go(theFrame)
        case 39:
            // Script #17 ('StartIntro')
            audioEngine.startAudio()
            startTimer()
            audioEngine.kinGlobal("cVolumetotal", value: 0.46, inlet: 0)
            audioEngine.kinGlobal("cTriggerevent3", value: 1.0, inlet: 0)
        case 40:
            // Script #16 ('Intro')
            if theTimer >= 20 * 60 {
                go(41)
            } else {
                go(theFrame)
            }
        case 41:
            // Script #14 ('Intro END')
            audioEngine.kinGlobal("cMusiclevel", value: 1.0, inlet: 1)
            audioEngine.kinGlobal("cTriggerevent2", value: gameState.gBackgroundindex, inlet: 0)
            audioEngine.kinGlobal("cVolumeevent3", value: 1.0, inlet: 0)
            theTimer = 0
            go(10)
        case 50:
            // Script #21 (Game Over start)
            audioEngine.kinGlobal("cVolumeevent1", value: 1.6, inlet: 0)
            audioEngine.kinGlobal("cTriggerevent1", value: 3.0, inlet: 0)
            gameState.gStemteller = 0.0
            go(theFrame + 1)
        case 51:
            // Script #22 ('New Marker')
            gameSpeedDown()
            gameState.gStemteller += 1.0
            if gameState.gStemteller <= 75.0 {
                go(theFrame)
            } else {
                gameState.gStemteller = 0.45
                go(theFrame + 1)
            }
        case 52:
            // Script #23
            gameSpeedDown()
            gameState.gStemteller -= 0.01
            audioEngine.kinGlobal("cVolumetotal", value: max(0.0, gameState.gStemteller), inlet: 0)
            if gameState.gStemteller <= 0.0 {
                go(theFrame + 1)
            } else {
                go(theFrame)
            }
        case 53:
            // Script #18
            audioEngine.stopAudio()
            audioEngine.cleanAll()
        case 55:
            // Script #26
            gameState.gScoreField = "\(gameState.gScore)"
            gameWriteFile()
        case 56:
            // Script #11
            audioEngine.stopAudio()
            go(1, movie: "score.dir")
        default:
            break
        }
        gameState.syncFields()
    }

    private func gameKeyDown(keyCode: UInt16, key: String) {
        // Allow Escape (53) to abort cleanly back to menu.dir (Script #19)
        if keyCode == DirectorKeyCode.escape {
            audioEngine.stopAudio()
            go(1, movie: "menu.dir")
        }
    }

    private func gameKeyUp(keyCode: UInt16) {
        // Script #22 (Frame 51) has its own on keyUp() handler that overrides Movie Script #28
        if currentFrame == 51 {
            return
        }
        // Script #28: on keyUp()
        if keyCode == DirectorKeyCode.left {
            if gameState.gCapLock == 0 {
                gameState.gCapLockTime = theTimer
                gameBoCapture()
            }
        }
        if keyCode == DirectorKeyCode.right {
            gameBoActivate()
        }
        gameState.syncFields()
    }

    // Movie Script #25: on writeFile()
    public func gameWriteFile() {
        let text = gameState.gScoreField
        guard !text.isEmpty else { return }
        highScoreStore.writeSData(text)
    }

    // Movie Script #28 Handlers:

    public func gameBoAanloop() {
        if gameState.gBoAfstand > 0 {
            gameState.gBoAfstand -= (gameState.gSpeed * gameState.gMeter)
            gameState.gBoVolume = (((gameState.gBoAfstand - 100.0) * -1.0) / 100.0)
            gameState.gMusicVolume = (0.5 + (0.005 * gameState.gBoAfstand))
            audioEngine.kinGlobal("cVolumeboosteraanloop", value: gameState.gBoVolume, inlet: 0)
        } else {
            audioEngine.kinGlobal("cTriggersample3", value: 1.0, inlet: 0)
            audioEngine.kinGlobal("cLoopsample3", value: 1.0, inlet: 0)
            go(theFrame + 1)
        }
    }

    public func gameBoActivate() {
        if gameState.gBoAmount >= 1 {
            if gameState.gSpeedMax < 700 {
                gameState.gSpeedMax += 100.0
                gameState.gBoTimer = 100
                gameState.gBoAmount -= 1
                if gameState.gBoAmount <= 0 {
                    gameState.gBoAmount = 0
                    audioEngine.kinGlobal("cLoopboosterevent", value: 0.0, inlet: 0)
                    audioEngine.kinGlobal("cTriggerboosterevent", value: 5.0, inlet: 0)
                }
                if abs(gameState.gSpeedMax - 799.0) < 1e-3 {
                    audioEngine.kinGlobal("cEvelien", value: 2.0, inlet: 1)
                    gameState.gScore += 1000
                }
            } else {
                gameBoNone()
            }
        } else {
            gameBoNone()
        }
    }

    public func gameBoAfloop() {
        if gameState.gBoAfstand > -200.0 {
            gameState.gBoAfstand -= (gameState.gSpeed * gameState.gMeter)
            gameState.gBoVolume = ((gameState.gBoAfstand + 200.0) / 100.0)
            gameState.gMusicVolume = ((gameState.gBoAfstand * -1.0) / 200.0)
            audioEngine.kinGlobal("cVolumeboosteraanloop", value: gameState.gBoVolume, inlet: 0)
        } else {
            gameState.gCounter = 0.0
            gameState.gBoAfstand = 100.0
            gameState.gBoVolume = 0.0
            gameState.gBoReady = 0
            audioEngine.kinGlobal("cVolumeboosteraanloop", value: gameState.gBoVolume, inlet: 0)
            go(10)
        }
    }

    public func gameBoInside() {
        if gameState.gBoAfstand > (-100.0 + (gameState.gSpeed / 10.0)) {
            gameState.gBoAfstand -= (gameState.gSpeed * gameState.gMeter)
        } else {
            audioEngine.kinGlobal("cLoopsample3", value: 0.0, inlet: 0)
            audioEngine.kinGlobal("cTriggersample3", value: 0.0, inlet: 0)
            go(theFrame + 1)
        }
    }

    public func gameBoCapture() {
        audioEngine.kinGlobal("cTriggerevent1", value: 2.0, inlet: 0)
        if gameState.gBoReady == 1 {
            if gameState.gBoAmount < 3 {
                gameState.gBoAmount += 1
                gameBoScore()
                gameState.gCounter = 0.0
                gameState.gBoAfstand = 100.0
                gameState.gBoVolume = 0.0
                gameState.gBoReady = 0
                gameState.gMusicVolume = 0.9
                audioEngine.kinGlobal("cTriggerboosterevent", value: 4.0, inlet: 0)
                audioEngine.kinGlobal("cVolumeboosteraanloop", value: gameState.gBoVolume, inlet: 0)
                audioEngine.kinGlobal("cLoopsample3", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cTriggersample3", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cVolumemusic", value: gameState.gMusicVolume, inlet: 0)
                if gameState.gBoAmount == 3 {
                    if gameState.gBoosterhehe == 5 {
                        audioEngine.kinGlobal("cEvelien", value: 35.0, inlet: 1)
                        gameState.gScore += 700
                        gameState.gBoosterhehe = 0
                    } else {
                        audioEngine.kinGlobal("cEvelien", value: 1.0, inlet: 1)
                        gameState.gScore += 700
                        gameState.gBoosterhehe += 1
                    }
                }
                go(10)
            } else {
                gameBoNone()
            }
        } else {
            gameBoNone()
        }
    }

    public func gameBoNone() {
        audioEngine.kinGlobal("cLoopboosterevent", value: 0.0, inlet: 0)
        audioEngine.kinGlobal("cTriggerboosterevent", value: 2.0, inlet: 0)
    }

    public func gameBoScore() {
        if gameState.gSpeed <= 99 {
            gameState.gScore += 100
        } else if gameState.gSpeed <= 199 {
            gameState.gScore += 200
        } else if gameState.gSpeed <= 299 {
            gameState.gScore += 300
        } else if gameState.gSpeed <= 399 {
            gameState.gScore += 400
        } else if gameState.gSpeed <= 499 {
            gameState.gScore += 500
        } else if gameState.gSpeed <= 599 {
            gameState.gScore += 600
        } else if gameState.gSpeed <= 699 {
            gameState.gScore += 800
        } else if gameState.gSpeed <= 799 {
            gameState.gScore += 1000
        }
    }

    public func gameBijder() {
        if gameState.gStartGa == 0 && gameState.gAfstand > 1.0 {
            let temp = Float(lingoRandom(5))
            gameState.gTwinCheck = temp
            audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
            gameState.gStartGa = 1
            gameState.gMusicIndex = 3.0
        }
        if gameState.gAfstand < 1.0 {
            gameState.gStartStil += 1
            if gameState.gStartStil == 4 {
                let temp = Float(lingoRandom(3)) + 26.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gStartStil = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gStartStil = 0
                    gameState.gTwinCheck = temp
                }
            }
            return
        }
        if gameState.gSpeed == 0.0 {
            gameState.gStaStil += 1
            if gameState.gStaStil == 7 {
                let temp = Float(lingoRandom(18)) + 5.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gStaStil = 0
                } else if gameState.gKotsRuler == 0 {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gStaStil = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 99.0 {
            gameState.gMusiclevel = gameState.gMusicIndex - 1.0
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed99 += 1
            if gameState.gConSpeed99 == 7 {
                let temp = Float(lingoRandom(15)) + 29.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed99 = 0
                } else if gameState.gKotsRuler == 0 {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed99 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 199.0 {
            gameState.gMusiclevel = gameState.gMusicIndex - 1.0
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed99 = 0
            gameState.gConSpeed199 += 1
            if gameState.gConSpeed199 == 7 {
                let temp = Float(lingoRandom(15)) + 29.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed199 = 0
                } else if gameState.gKotsRuler == 0 {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed199 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 299.0 {
            gameState.gMusiclevel = gameState.gMusicIndex - 1.0
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed199 = 0
            gameState.gConSpeed299 += 1
            if gameState.gConSpeed299 == 7 {
                let temp = Float(lingoRandom(11)) + 44.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed299 = 0
                } else if gameState.gKotsRuler == 0 {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed299 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 399.0 {
            gameState.gMusiclevel = gameState.gMusicIndex
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed299 = 0
            gameState.gConSpeed399 += 1
            if gameState.gConSpeed399 == 7 {
                let temp = Float(lingoRandom(16)) + 44.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed399 = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed399 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 499.0 {
            gameState.gMusiclevel = gameState.gMusicIndex
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed399 = 0
            gameState.gConSpeed499 += 1
            if gameState.gConSpeed499 == 7 {
                let temp = Float(lingoRandom(16)) + 44.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed499 = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed499 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 599.0 {
            gameState.gMusiclevel = gameState.gMusicIndex
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed499 = 0
            gameState.gConSpeed599 += 1
            if gameState.gConSpeed599 == 7 {
                let temp = Float(lingoRandom(19)) + 60.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed599 = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed599 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 699.0 {
            gameState.gMusiclevel = gameState.gMusicIndex + 1.0
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed599 = 0
            gameState.gConSpeed699 += 1
            if gameState.gConSpeed699 == 7 {
                let temp = Float(lingoRandom(19)) + 79.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed699 = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed699 = 0
                }
            }
            return
        }
        if gameState.gSpeed <= 799.0 {
            gameState.gMusiclevel = gameState.gMusicIndex + 1.0
            audioEngine.kinGlobal("cMusiclevel", value: gameState.gMusiclevel, inlet: 1)
            gameState.gConSpeed699 = 0
            gameState.gConSpeed799 += 1
            if gameState.gConSpeed799 == 7 {
                let temp = Float(lingoRandom(19)) + 79.0
                if gameState.gTwinCheck == temp {
                    gameState.gTwinCheck = 0.0
                    gameState.gConSpeed799 = 0
                } else {
                    audioEngine.kinGlobal("cBijrijder", value: temp, inlet: 1)
                    gameState.gTwinCheck = temp
                    gameState.gConSpeed799 = 0
                }
            }
        }
    }

    public func gameBreakStop() {
        if gameState.gBreakStop == 1 {
            gameState.gBreakTimer += 1
            if gameState.gBreakTimer >= 100 {
                gameState.gMusicIndex += 3.0
                gameState.gBreakStop = 0
            }
        }
    }

    public func gameCapLock() {
        if (gameState.gCapLockTime + 100) <= theTimer {
            gameState.gCapLock = 0
        } else {
            gameState.gCapLock = 1
        }
    }

    public func gameCheckPoint() {
        if (gameState.gAfstand - gameState.gAfstandtemp1) >= 1000.0 {
            gameState.gAfstandtemp2 += 1.0
            gameState.gIndextemp += 1
            gameState.gMusicIndex += 3.0
            gameState.gScore += 400
            if gameState.gAfstand >= 4000.0 && gameState.gAfstand <= 4100.0 {
                gameState.gBreakStop = 1
            }
            if gameState.gMusicIndex >= 22.0 {
                gameState.gMusicIndex = 21.0
            }
            if gameState.gIndextemp == 3 {
                gameState.gBackgroundindex += 3.0
                audioEngine.kinGlobal("cTriggerevent2", value: gameState.gBackgroundindex, inlet: 0)
                gameState.gIndextemp = 0
            }
            audioEngine.kinGlobal("cEvelien", value: gameState.gAfstandtemp2, inlet: 1)
            gameState.gAfstandtemp1 = gameState.gAfstand
        }
    }

    public func gameEventCheck() {
        let check = lingoRandom(100)
        if check >= 2 && check <= 35 {
            audioEngine.kinGlobal("cVolumeboosteraanloop", value: 0.0, inlet: 0)
            audioEngine.kinGlobal("cBoosteraanlooploop", value: 1.0, inlet: 0)
            audioEngine.kinGlobal("cBoosteraanloop", value: 1.0, inlet: 0)
            gameState.gBoBaan = 0
            go(20)
        }
        if check >= 36 && check <= 100 {
            gameState.gBoBaan += 1
            if gameState.gBoBaan == 2 {
                audioEngine.kinGlobal("cVolumeboosteraanloop", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cBoosteraanlooploop", value: 1.0, inlet: 0)
                audioEngine.kinGlobal("cBoosteraanloop", value: 1.0, inlet: 0)
                gameState.gBoBaan = 0
                go(20)
                return
            }
            let check2 = lingoRandom(4)
            if check2 == 1 {
                go(25)
                return
            }
            let check3 = lingoRandom(2)
            if check3 == 1 {
                if gameState.gBackgroundindex == 1.0 {
                    let sfx = Float(lingoRandom(6)) + 1.0
                    audioEngine.kinGlobal("cTriggerevent3", value: sfx, inlet: 0)
                } else if gameState.gBackgroundindex == 4.0 {
                    let sfx = Float(lingoRandom(6)) + 7.0
                    audioEngine.kinGlobal("cTriggerevent3", value: sfx, inlet: 0)
                } else if gameState.gBackgroundindex == 7.0 {
                    let sfx = Float(lingoRandom(6)) + 13.0
                    audioEngine.kinGlobal("cTriggerevent3", value: sfx, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 1 {
                if gameState.gSpeed <= 299 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 1.0, inlet: 0)
                } else if gameState.gSpeed <= 599 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 2.0, inlet: 0)
                } else {
                    audioEngine.kinGlobal("cTriggerevent4", value: 3.0, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 2 {
                if gameState.gSpeed <= 299 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 4.0, inlet: 0)
                } else if gameState.gSpeed <= 599 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 5.0, inlet: 0)
                } else {
                    audioEngine.kinGlobal("cTriggerevent4", value: 6.0, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 3 {
                if gameState.gSpeed <= 299 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 7.0, inlet: 0)
                } else if gameState.gSpeed <= 599 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 8.0, inlet: 0)
                } else {
                    audioEngine.kinGlobal("cTriggerevent4", value: 9.0, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 4 {
                if gameState.gSpeed <= 299 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 10.0, inlet: 0)
                } else if gameState.gSpeed <= 599 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 11.0, inlet: 0)
                } else {
                    audioEngine.kinGlobal("cTriggerevent4", value: 12.0, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 5 {
                if gameState.gSpeed <= 299 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 13.0, inlet: 0)
                } else if gameState.gSpeed <= 599 {
                    audioEngine.kinGlobal("cTriggerevent4", value: 14.0, inlet: 0)
                } else {
                    audioEngine.kinGlobal("cTriggerevent4", value: 15.0, inlet: 0)
                }
                return
            }
            if lingoRandom(6) == 6 {
                audioEngine.kinGlobal("cTriggerevent4", value: 16.0, inlet: 0)
            }
        }
    }

    public func gameInterCheck() {
        gameState.gCounter += (gameState.gSpeed * gameState.gMeter)
        if gameState.gCounter > gameState.gInterval {
            gameEventCheck()
            gameState.gCounter = 0.0
        }
    }

    public func gameKeyCheck() {
        if keyPressed(DirectorKeyCode.up) {
            if gameState.gKeyLock == 0 {
                if gameState.gSpeed < gameState.gSpeedMax {
                    gameSpeedUp()
                    gameSetAfstand()
                } else {
                    gameSetAfstand()
                }
            } else {
                gameSetAfstand()
            }
        } else {
            if gameState.gSpeed > 0 {
                gameSpeedDown()
                gameSetAfstand()
            }
        }
        if keyPressed(DirectorKeyCode.space) {
            gameRem()
        }
    }

    public func gameKotsRuler() {
        if gameState.gKotsRuler == 1 {
            gameState.gKotsteller += 1
            if gameState.gKotsteller == 10 {
                gameState.gKotsRuler = 0
                gameState.gKotsteller = 0
            }
        }
    }

    public func gameRem() {
        if gameState.gSpeed < gameState.gRem {
            gameState.gSpeed = 0.0
            gameState.gRemIn = 0
        } else {
            gameState.gSpeed -= gameState.gRem
            audioEngine.kinGlobal("cTriggerrem", value: 1.0, inlet: 0)
            gameState.gRemIn += 1
            if gameState.gRemIn >= 15 {
                gameState.gRemIn = 0
                gameState.gSick += 1.0
                if gameState.gSick >= 26.0 {
                    gameState.gSick = 26.0
                    gameState.gScore += 1500
                }
                audioEngine.kinGlobal("cBijrijder", value: gameState.gSick, inlet: 1)
                gameState.gKotsRuler = 1
            }
        }
    }

    public func gameSetAfstand() {
        gameState.gAfstand += (gameState.gSpeed * gameState.gMeter)
    }

    public func gameSpeedDown() {
        gameState.gSpeed -= gameState.gStroop
        if gameState.gSpeed < 0.0 {
            gameState.gSpeed = 0.0
        }
        audioEngine.kinGlobal("cSnelheid", value: gameState.gSpeed, inlet: 0)
        if gameState.gSpeed <= 200.0 {
            gameState.gBackVolume = (((gameState.gSpeed / 200.0) * -1.0) + 1.0)
            if gameState.gBackVolume > 1.0 {
                gameState.gBackVolume = 1.0
            }
            audioEngine.kinGlobal("cVolumeevent2", value: gameState.gBackVolume, inlet: 0)
        }
    }

    public func gameSpeedUp() {
        gameState.gSpeed += gameState.gAccel
        if gameState.gSpeed > gameState.gSpeedMax {
            gameState.gSpeed = gameState.gSpeedMax
        }
        audioEngine.kinGlobal("cSnelheid", value: gameState.gSpeed, inlet: 0)
        if gameState.gSpeed > 0.0 {
            gameState.gBackVolume = (((gameState.gSpeed / 200.0) * -1.0) + 1.0)
            if gameState.gBackVolume < 0.0 {
                gameState.gBackVolume = 0.0
            }
            audioEngine.kinGlobal("cVolumeevent2", value: gameState.gBackVolume, inlet: 0)
        }
    }

    public func gameSWAanloop() {
        if gameState.gSWAfstand > 0.0 {
            gameState.gSWAfstand -= (gameState.gSpeed * gameState.gMeter)
            gameState.gSWVolume = (((gameState.gSWAfstand - 500.0) * -1.0) / 500.0)
        } else {
            gameState.gSWReady = 1
            go(31)
        }
    }

    public func gameSWAfloop() {
        if gameState.gSWAfstand > -200.0 {
            gameState.gSWAfstand -= (gameState.gSpeed * gameState.gMeter)
            gameState.gSWVolume = ((gameState.gSWAfstand + 100.0) / 100.0)
        } else {
            gameState.gCounter = 0.0
            gameState.gSWAfstand = 500.0
            gameState.gSWVolume = 0.0
            gameState.gSWReady = 0
            go(10)
        }
    }

    public func gameSWInside() {
        if gameState.gSWAfstand > -100.0 {
            gameState.gSWAfstand -= (gameState.gSpeed * gameState.gMeter)
        } else {
            gameState.gScore += 500
            go(32)
        }
    }

    public func gameShiftCheck() {
        if gameState.gBoTimer > 0 {
            gameState.gBoTimer -= 1
            if gameState.gBoTimer == 29 {
                audioEngine.kinGlobal("cLoopboosterevent", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cTriggerboosterevent", value: 7.0, inlet: 0)
            }
            if gameState.gBoTimer == 1 {
                gameState.gSpeedMax -= 100.0
                gameState.gKeyLock = 0
                audioEngine.kinGlobal("cLoopboosterevent", value: 0.0, inlet: 0)
                audioEngine.kinGlobal("cTriggerboosterevent", value: 6.0, inlet: 0)
                if gameState.gSpeedMax < 99.0 {
                    gameState.gSpeedMax = 99.0
                }
                gameState.gBoTimer = 0
            }
        }
        if gameState.gBoTimer == 0 && gameState.gSpeedMax > 99.0 && gameState.gKeyLock == 0 {
            gameState.gBoTimer = 30
        }
    }

    public func gameShiftDwn() {
        if gameState.gSpeed > gameState.gSpeedMax {
            gameState.gKeyLock = 1
            gameSpeedDown()
        } else {
            gameState.gKeyLock = 0
        }
    }

    public func gameTimeAder() {
        gameState.gTimeAder += 1
        if (gameState.gTimeAder - gameState.gTAtemp1) == 12 {
            gameCheckPoint()
            gameBijder()
            gameState.gTAtemp1 = gameState.gTimeAder
        }
        if theTimer >= 10800 {
            go(50)
        }
        if gameState.gEndLock == 1 {
            audioEngine.kinGlobal("cEvelien", value: 32.0, inlet: 1)
            gameState.gEndLock += 1
        } else if gameState.gEndLock == 3 {
            audioEngine.kinGlobal("cEvelien", value: 31.0, inlet: 1)
            gameState.gEndLock += 1
        } else if gameState.gEndLock == 5 {
            audioEngine.kinGlobal("cEvelien", value: 30.0, inlet: 1)
            gameState.gEndLock += 1
        } else if gameState.gEndLock == 7 {
            audioEngine.kinGlobal("cEvelien", value: 29.0, inlet: 1)
            gameState.gEndLock += 1
        } else if gameState.gEndLock == 9 {
            audioEngine.kinGlobal("cEvelien", value: 28.0, inlet: 1)
            gameState.gEndLock += 1
        }
    }

    public func gameEndCheck() {
        if (gameState.gEndLockTime + 1800) <= theTimer {
            gameState.gEndLock += 1
            gameState.gEndLockTime = theTimer
        }
    }

    // MARK: - 4. SCORE MOVIE (score.dxr)

    private func scoreStartMovie() {
        let hi = highScoreStore.loadHighScore()
        scoreState = ScoreMovieState()
        scoreState.gCharNum = 0
        scoreState.gKnoppie = 0
        scoreState.gInvoer = 0
        scoreState.gInvoerSet = 0
        scoreState.musicFade1 = 1.0
        scoreState.gScoreField3 = "\(hi.score)"
        scoreState.lHiScore = hi.score
        scoreState.gNameField2 = hi.name
    }

    // score.dxr Script #1: on readFile()
    public func scoreReadFile() {
        let fileText = highScoreStore.readSData() ?? scoreState.gScoreField2
        scoreState.gScoreField2 = fileText
        let chars = Array(fileText)
        let tNum = chars.count
        scoreState.numberField = "\(tNum)"

        func digitAt(_ oneBasedIndex: Int) -> Float {
            let idx = oneBasedIndex - 1
            guard idx >= 0 && idx < chars.count, let d = Int(String(chars[idx])) else {
                return 0.0
            }
            return Float(d)
        }

        if tNum >= 3 {
            if tNum == 5 {
                scoreState.gDuizend = digitAt(tNum - 3) + (digitAt(tNum - 4) * 10.0)
                scoreState.gHonderd = digitAt(tNum - 2) * 1.0
            } else if tNum == 4 {
                scoreState.gDuizend = 0.0
                scoreState.gHonderd = (digitAt(tNum - 3) * 10.0) + digitAt(tNum - 2)
                if scoreState.gHonderd > 19.0 {
                    scoreState.gDuizend = digitAt(tNum - 3) * 1.0
                    scoreState.gHonderd = digitAt(tNum - 2) * 1.0
                }
            } else if tNum > 5, let fullVal = Int(fileText) {
                scoreState.gDuizend = Float(fullVal / 1000)
                scoreState.gHonderd = Float((fullVal % 1000) / 100)
            } else {
                scoreState.gDuizend = 0.0
                scoreState.gHonderd = digitAt(tNum - 2) * 1.0
            }
        } else {
            scoreState.gHonderd = 0.0
            scoreState.gDuizend = 0.0
        }
    }

    // score.dxr Script #16: Load ScoreSampler
    public func scoreLoadScoreSampler() {
        let gDuizend = scoreState.gDuizend
        let gHonderd = scoreState.gHonderd

        audioEngine.kinGlobal("cScore1", value: 68.0, inlet: 0)
        audioEngine.kinGlobal("cScore2", value: gDuizend, inlet: 0)
        if gDuizend > 65.0 {
            audioEngine.kinGlobal("cScore2", value: 72.0, inlet: 0)
        }
        if gDuizend > 0.0 {
            audioEngine.kinGlobal("cScore3", value: 67.0, inlet: 0)
        } else {
            audioEngine.kinGlobal("cScore3", value: 0.0, inlet: 0)
        }
        audioEngine.kinGlobal("cScore4", value: gHonderd, inlet: 0)
        if gHonderd == 1.0 && gDuizend != 1.0 {
            audioEngine.kinGlobal("cScore4", value: 0.0, inlet: 0)
        }
        if gHonderd > 0.0 {
            audioEngine.kinGlobal("cScore5", value: 66.0, inlet: 0)
        } else {
            audioEngine.kinGlobal("cScore5", value: 0.0, inlet: 0)
        }
        if gHonderd == 0.0 && gDuizend == 0.0 {
            audioEngine.kinGlobal("cScore4", value: 71.0, inlet: 0)
        }
        audioEngine.kinGlobal("cScore6", value: 69.0, inlet: 0)
        audioEngine.kinGlobal("cScore7", value: 0.0, inlet: 0)
    }

    // score.dxr Script #1: postText() & postText2() -> local persistent high score
    public func scorePostText() {
        var record = highScoreStore.loadHighScore()
        if let newScore = Int(scoreState.gScoreField2) {
            record.score = newScore
            scoreState.lHiScore = newScore
            scoreState.gScoreField3 = "\(newScore)"
        }
        highScoreStore.saveHighScore(record)
    }

    public func scorePostText2() {
        var record = highScoreStore.loadHighScore()
        let trimmedName = scoreState.gNameField2.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            record.name = trimmedName
        }
        highScoreStore.saveHighScore(record)
    }

    private func scoreExitFrame(_ frame: Int) {
        switch frame {
        case 2:
            // Script #0 ('CPS')
            audioEngine.executePatch(named: "score_cps_graph")
        case 3:
            // Script #23 ('SetFlag')
            scoreState.gFlag = 1
        case 4:
            // Script #44
            audioEngine.kinGlobal("cTriggermusic", value: 1.0, inlet: 1)
        case 5:
            // Script #2 ('ReadFile IO')
            scoreReadFile()
        case 8:
            // Script #16 ('Load ScoreSampler')
            scoreLoadScoreSampler()
        case 10:
            // Script #42
            audioEngine.kinGlobal("cStartscore", value: 1.0, inlet: 0)
        case 15:
            // Script #43
            startTimer()
        case 16:
            // Script #46
            if theTimer < 60 * 5 {
                go(theFrame)
            } else {
                go(theFrame + 1)
            }
        case 17:
            // Script #24
            if scoreState.gFlag == 1 {
                go(48)
            }
        case 30:
            // Script #45 ('score\druktoets.hrs')
            audioEngine.kinGlobal("cTriggersampler1", value: 5.0, inlet: 1)
        case 33:
            // Script #37
            if scoreState.gInvoer == 1 {
                go(50)
            } else {
                go(theFrame + 1)
            }
        case 35:
            // Script #13 ('klaar met eve score zeggen', label 'klaar&wacht')
            scoreState.gTimer = 0
            if scoreState.gInvoer == 1 {
                scoreState.gInvoer = 2
            }
        case 36:
            // Script #14
            scoreState.gTimer += 1
            if scoreState.gTimer == 100 {
                go(10)
            } else {
                go(theFrame)
            }
        case 42:
            // Script #21
            if scoreState.musicFade1 > 0.0 {
                scoreState.musicFade1 -= 0.01
                audioEngine.kinGlobal("cVolumemusic", value: max(0.0, scoreState.musicFade1), inlet: 0)
                go(theFrame)
            } else {
                audioEngine.stopAudio()
                go(1, movie: "menu.dir")
            }
        case 48:
            // Script #25 (Local high-score fetch replacing getNetText)
            scoreState.gScoreField3 = ""
            scoreState.gNetTeller = 0
        case 49:
            // Script #26 (Local high-score result ready)
            let record = highScoreStore.loadHighScore()
            scoreState.gScoreField3 = "\(record.score)"
            scoreState.lHiScore = record.score
            go(theFrame + 1)
        case 50:
            // Script #28 ('scorecheck!', label 'scoreverschil')
            let lScore = Int(scoreState.gScoreField2) ?? 0
            let lHiScore = Int(scoreState.gScoreField3)
            scoreState.lScore = lScore
            guard let hi = lHiScore else {
                scoreState.gInvoer = 2
                scoreState.gFlag = 0
                go(26)
                return
            }
            scoreState.lHiScore = hi
            if lScore > hi {
                startTimer()
                audioEngine.kinGlobal("cTriggersampler1", value: 1.0, inlet: 1)
                go(theFrame + 1)
            } else {
                scoreState.gInvoer = 2
                scoreState.gFlag = 0
                go(26)
            }
        case 51:
            // Script #47
            if theTimer < 60 * 4 {
                go(theFrame)
            } else {
                go(theFrame + 1)
            }
        case 53:
            // Script #31
            go(theFrame + 1)
        case 54:
            // Script #32 ('score\naam.hrs')
            audioEngine.kinGlobal("cTriggersampler1", value: 2.0, inlet: 1)
        case 55:
            // Script #33
            scoreState.gNameField = ""
            scoreState.gNameField2 = ""
            scoreState.gCharNum = 0
            go(theFrame + 1)
        case 57:
            // Script #34 ('typnaamloop')
            scoreState.gInvoer = 1
            go(theFrame)
        case 60:
            // Script #40
            scoreState.gTimer = 0
        case 61:
            // Script #41
            scoreState.gTimer += 1
            if scoreState.gTimer == 25 {
                scoreState.gTimer = 0
                go(theFrame + 1)
            } else {
                go(theFrame)
            }
        case 68:
            // Script #29 ('hi score op server')
            scorePostText()
        case 75:
            // Script #38 ('naam op server')
            scorePostText2()
        case 85:
            // Script #30
            scoreState.gInvoer = 2
            scoreState.gFlag = 0
            go(26)
        case 95:
            // Script #39
            go(26)
        default:
            break
        }
    }

    private func scoreKeyDown(keyCode: UInt16, key: String) {
        // Script #1: on keyDown()
        if scoreState.gInvoer == 1 {
            if let scalar = key.unicodeScalars.first {
                let lChar = Int(scalar.value)
                if (lChar >= 65 && lChar <= 90) || (lChar >= 97 && lChar <= 122) {
                    scoreState.gCharNum += 1
                    audioEngine.kinGlobal("cTriggersampler1", value: 3.0, inlet: 1)
                    if scoreState.gCharNum >= 15 {
                        audioEngine.kinGlobal("cTriggersampler1", value: 4.0, inlet: 1)
                        scoreState.gInvoer = 3
                        go(60)
                    }
                    let chStr = String(Character(scalar))
                    scoreState.gNameField = chStr
                    scoreState.gNameField2 += chStr
                    return
                }
            }
            if keyCode == DirectorKeyCode.backspace {
                if !scoreState.gNameField2.isEmpty {
                    scoreState.gNameField2.removeLast()
                    scoreState.gCharNum = max(0, scoreState.gCharNum - 1)
                    audioEngine.kinGlobal("cTriggersampler1", value: 3.0, inlet: 1)
                }
                return
            }
            if keyCode == DirectorKeyCode.returnKey {
                audioEngine.kinGlobal("cTriggersampler1", value: 4.0, inlet: 1)
                scoreState.gInvoer = 3
                go(60)
                return
            }
        }

        if scoreState.gInvoer == 2 {
            audioEngine.kinGlobal("cTriggersampler1", value: 4.0, inlet: 1)
            go(40)
        }
    }

    // MARK: - 5. QUIT MOVIE (quit.dxr)

    private func quitExitFrame(_ frame: Int) {
        switch frame {
        case 2:
            // Script #22 (Chunk 267)
            audioEngine.executePatch(named: "quit_cps")
        case 9:
            // Script #3 (Chunk 264)
            if theTimer < 60 * 22 {
                go(theFrame)
            } else {
                audioEngine.stopAudio()
                didQuit = true
            }
        default:
            break
        }
    }

    private func quitKeyDown(keyCode: UInt16, key: String) {
        guard currentFrame == 9 else { return }
        if key == " " || keyCode == DirectorKeyCode.space || keyCode == DirectorKeyCode.escape {
            audioEngine.stopAudio()
            didQuit = true
        }
    }

    // MARK: - Accessibility & Visual Telemetry Description

    public var accessibilityStatusDescription: String {
        switch currentMovie {
        case .intro:
            let secLeft = max(0, 36 - (theTimer / 60))
            return "Drive Intro. Press Spacebar to skip to Menu (\(secLeft)s remaining)."
        case .menu:
            let optionName: String
            switch menuState.menuCounter {
            case 1: optionName = "1: Spelen (Play Game)"
            case 2: optionName = "2: Informatie (Information)"
            case 3: optionName = "3: Training (Tutorial)"
            case 4: optionName = "4: Stoppen (Quit)"
            default: optionName = "Use Up/Down or Left/Right arrows to choose, Enter to confirm"
            }
            if currentFrame == 61 {
                return "Drive Menu - Information. Press Spacebar to return to menu."
            } else if currentFrame == 71 {
                return "Drive Menu - Training Tutorial. Press Spacebar to return to menu."
            } else if currentFrame == 81 {
                return "Drive Menu - Quit Confirmation. Press Enter to quit or any other key to cancel."
            }
            return "Drive Main Menu. Selected: \(optionName)."
        case .game:
            if currentFrame >= 39 && currentFrame <= 41 {
                return "Drive Game - Starting Shuttle Engine..."
            }
            if currentFrame >= 50 {
                return "Drive Game Over - Final Score: \(gameState.gScore)"
            }
            let zone: String
            switch currentFrame {
            case 20: zone = "Booster Approaching"
            case 21: zone = "IN BOOSTER ZONE (Press Left Arrow to Capture!)"
            case 22: zone = "Booster Passing"
            case 25: zone = "Event Zone"
            case 30...32: zone = "SoundWarp Zone"
            default: zone = "FreeDrive"
            }
            let secRemaining = max(0, 180 - (theTimer / 60))
            return String(
                format: "Drive Game [%@] | Speed: %.0f / %.0f (Gear %d) | Boosters: %d/3 | Distance: %.0fm | Score: %d | Time Left: %ds",
                zone,
                gameState.gSpeed,
                gameState.gSpeedMax,
                gameState.currentGear,
                gameState.gBoAmount,
                gameState.gAfstand,
                gameState.gScore,
                secRemaining
            )
        case .score:
            if scoreState.gInvoer == 1 {
                return "Drive New High Score (\(scoreState.gScoreField2))! Type your name (A-Z) and press Enter: \(scoreState.gNameField2)"
            }
            return "Drive Score Screen | Your Score: \(scoreState.gScoreField2) | High Score: \(scoreState.gScoreField3) (\(scoreState.gNameField2)) | Press any key to return to Menu."
        case .quit:
            return "Drive Credits / Quit Screen. Press Spacebar to exit immediately."
        }
    }
}
