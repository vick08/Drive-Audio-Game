import Foundation

public enum VerifySuite {
    private static var passedCount = 0
    private static var failedCount = 0

    private static func check(_ condition: Bool, _ message: String) {
        if condition {
            passedCount += 1
            print("  [PASS] \(message)")
        } else {
            failedCount += 1
            print("  [FAIL] \(message)")
        }
    }

    public static func runAll(xtrasURL: URL, picsURL: URL, patchesJSONURL: URL) -> Bool {
        passedCount = 0
        failedCount = 0

        print("================================================================================")
        print("DRIVE (2002) - NATIVE MACOS PORT VERIFICATION SUITE (--verify)")
        print("================================================================================")

        let engine = CPSAudioEngine(xtrasURL: xtrasURL, patchesJSONURL: patchesJSONURL)

        // -------------------------------------------------------------------------
        // 1. CPS Audio Patches, WAV Cache & 5-Gear Procedural Motor Synthesizer
        // -------------------------------------------------------------------------
        print("\n--- 1. CPS Audio Engine & Procedural Motor Synthesis ---")
        check(engine.patchDefinitions.count == 7, "Loaded all 7 CPS patch definitions from cps_patches.json (\(engine.patchDefinitions.count))")

        let haven2 = engine.wavCache.sample(for: "sfx\\haven2.hrs")
        let cycom5 = engine.wavCache.sample(for: "sfx\\cycom5.hrs")
        check(haven2 != nil && haven2!.frameCount > 44100, "16 kHz mono WAV (sfx\\haven2.hrs) loaded and resampled to 44.1 kHz (\(haven2?.frameCount ?? 0) frames)")
        check(cycom5 != nil && cycom5!.frameCount > 44100, "22.05 kHz stereo WAV (sfx\\cycom5.hrs) loaded and resampled to 44.1 kHz (\(cycom5?.frameCount ?? 0) frames)")

        let builtGame = engine.executePatch(named: "game_cps_graph") && engine.executePatch(named: "game_cps_init")
        check(builtGame && engine.nodesByID.count == 225, "Built 225-node game.dxr CPS graph + init (\(engine.nodesByID.count) nodes, \(engine.wavCache.loadedSampleCount) loaded WAVs, \(engine.wavCache.missingSampleCount) missing placeholders)")

        engine.kinGlobal("cVolumetotal", value: 0.46, inlet: 0)
        var allGearsProduceAudio = true
        for speed: Float in [0, 50, 150, 250, 350, 450, 650, 750] {
            engine.kinGlobal("cSnelheid", value: speed, inlet: 0)
            let stats = engine.processBlocks(8)
            if stats.rmsLeft <= 0.001 || !stats.rmsLeft.isFinite {
                allGearsProduceAudio = false
            }
        }
        check(allGearsProduceAudio, "5-gear procedural shuttle motor synthesizer produces clean audio across speeds 0..750")

        // -------------------------------------------------------------------------
        // 2. IntroMovie (intro.dxr)
        // -------------------------------------------------------------------------
        print("\n--- 2. IntroMovie (intro.dxr) ---")
        let runtime = DirectorRuntime(audioEngine: engine, xtrasURL: xtrasURL, picsURL: picsURL)
        check(runtime.currentMovie == .intro && runtime.currentFrame == 1, "Runtime starts at intro.dir Frame 1")

        // Step to Frame 9
        while runtime.currentMovie == .intro && runtime.currentFrame < 9 {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .intro && runtime.currentFrame == 9, "IntroMovie reached loop Frame 9 with audio running (\(engine.isAudioRunning))")
        let introStats = engine.processBlocks(16)
        check(introStats.rmsLeft > 0.01 && introStats.rmsRight > 0.01, String(format: "IntroMovie playing start/start.hrs stereo audio (RMS L=%.4f R=%.4f)", introStats.rmsLeft, introStats.rmsRight))

        // Test 36-second timer completion -> MenuMovie
        while runtime.currentMovie == .intro {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .menu && runtime.currentFrame == 1, "IntroMovie 36-second timer (2160 ticks) transitions to menu.dir Frame 1")

        // Also test Spacebar skip on IntroMovie
        runtime.loadMovie(.intro, frame: 1)
        while runtime.currentMovie == .intro && runtime.currentFrame < 9 {
            runtime.stepFrame()
        }
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        check(runtime.currentMovie == .menu && runtime.currentFrame == 1, "IntroMovie Spacebar press at Frame 9 skips immediately to menu.dir Frame 1")

        // -------------------------------------------------------------------------
        // 3. MenuMovie (menu.dxr)
        // -------------------------------------------------------------------------
        print("\n--- 3. MenuMovie (menu.dxr) ---")
        while runtime.currentMovie == .menu && runtime.currentFrame < 13 {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .menu && runtime.currentFrame == 13, "MenuMovie initialized menu_cps, triggered eve01+snd3 at Frame 10, and entered Menu LOOP at Frame 13")
        let menuAudioStats = engine.processBlocks(16)
        check(menuAudioStats.rmsLeft > 0.01, String(format: "MenuMovie playing intro.hrs + Evelien voice prompt (RMS L=%.4f)", menuAudioStats.rmsLeft))

        // Test idle timeout (gTemp > 400 -> Frame 10 -> 11 -> 12 -> 13)
        for _ in 0..<401 {
            runtime.stepFrame()
        }
        check(runtime.currentFrame == 11, "MenuMovie idle counter (gTemp > 400) jumped back to Frame 10 -> 11 to repeat prompt")
        while runtime.currentFrame < 13 {
            runtime.stepFrame()
        }

        // Test Down/Right/Up/Left cycling of menuCounter 1..4
        runtime.handleKeyDown(keyCode: DirectorKeyCode.down)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.down)
        let c1 = runtime.menuState.menuCounter
        runtime.handleKeyDown(keyCode: DirectorKeyCode.right)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.right)
        let c2 = runtime.menuState.menuCounter
        runtime.handleKeyDown(keyCode: DirectorKeyCode.down)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.down)
        let c3 = runtime.menuState.menuCounter
        runtime.handleKeyDown(keyCode: DirectorKeyCode.down)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.down)
        let c4 = runtime.menuState.menuCounter
        // Up arrow: first press sets var=1 and calls menuomlaag (-> 1), second press calls menuomhoog (-> 4)
        runtime.handleKeyDown(keyCode: DirectorKeyCode.up)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.up)
        let cUp1 = runtime.menuState.menuCounter
        runtime.handleKeyDown(keyCode: DirectorKeyCode.up)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.up)
        let cUp2 = runtime.menuState.menuCounter
        check([c1, c2, c3, c4, cUp1, cUp2] == [1, 2, 3, 4, 1, 4], "MenuMovie arrow navigation cycles menuCounter 1..4 accurately (\([c1, c2, c3, c4, cUp1, cUp2]))")

        // Select Option 2 (INFO -> Frame 60 -> 61) and skip with Spacebar
        runtime.menuState.menuCounter = 2
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 13 exitFrame -> enterding() -> go(60)
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 60 exitFrame -> 61
        let reachedInfo = (runtime.currentFrame == 61)
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.space, characters: " ")
        while runtime.currentFrame < 13 {
            runtime.stepFrame()
        }
        check(reachedInfo && runtime.currentFrame == 13, "MenuMovie Option 2 (Info) plays eve08 at Frame 60-61 and Spacebar returns to Menu LOOP Frame 13")

        // Select Option 3 (TRAINING -> Frame 70 -> 71) and skip with Spacebar
        runtime.menuState.menuCounter = 3
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 13 -> 70
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 70 -> 71
        let reachedTraining = (runtime.currentFrame == 71)
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.space, characters: " ")
        while runtime.currentFrame < 13 {
            runtime.stepFrame()
        }
        check(reachedTraining && runtime.currentFrame == 13, "MenuMovie Option 3 (Training) plays eve09 at Frame 70-71 and Spacebar returns to Menu LOOP Frame 13")

        // Select Option 4 (STOPPEN -> Frame 80 -> 81) and cancel with Spacebar
        runtime.menuState.menuCounter = 4
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 13 -> 80
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 80 -> 81
        let reachedQuitPrompt = (runtime.currentFrame == 81)
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.space, characters: " ")
        while runtime.currentFrame < 13 {
            runtime.stepFrame()
        }
        check(reachedQuitPrompt && runtime.currentFrame == 13, "MenuMovie Option 4 (Quit) cancels back to Frame 13 when non-Return key is pressed")

        // Select Option 1 (SPELEN -> Frame 50 -> 51 -> 100 music fade -> GameMovie)
        runtime.menuState.menuCounter = 1
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 13 -> 50
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        while runtime.currentMovie == .menu {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .game && runtime.currentFrame == 1, "MenuMovie Option 1 (Spelen) plays eve07, fades music at Frame 100, and transitions to game.dir Frame 1")

        // -------------------------------------------------------------------------
        // 4. GameMovie (game.dxr)
        // -------------------------------------------------------------------------
        print("\n--- 4. GameMovie (game.dxr) ---")
        // Step through startup (1 -> 5 CPS -> 7 Init -> 9 -> 39 StartIntro -> 40 Intro 20s -> 41 Intro END -> 10 FreeDrive)
        while runtime.currentMovie == .game && runtime.currentFrame != 40 {
            runtime.stepFrame()
        }
        check(runtime.currentFrame == 40 && engine.isAudioRunning, "GameMovie reached Frame 40 (20s engine start intro)")
        let engineStartStats = engine.processBlocks(16)
        check(engineStartStats.rmsLeft > 0.01, String(format: "GameMovie Frame 40 playing sfx\\enginestart.hrs + motor synth (RMS L=%.4f)", engineStartStats.rmsLeft))

        while runtime.currentMovie == .game && runtime.currentFrame != 10 {
            runtime.stepFrame()
        }
        check(runtime.currentFrame == 10 && runtime.theTimer == 0, "GameMovie completed 20s intro at Frame 41 and entered FreeDrive at Frame 10 with timer=0")

        // Force deterministic EventCheck (>35 & check2 != 1 & check3 == 1 so it stays in FreeDrive during basic acceleration test)
        runtime.customRandomGenerator = { maxVal in
            if maxVal == 100 { return 50 }
            if maxVal == 4 { return 2 }
            if maxVal == 2 { return 1 }
            return 1
        }
        // Keep gBoBaan = 0 during pure acceleration test
        for _ in 0..<55 {
            runtime.gameState.gBoBaan = 0
            runtime.handleKeyDown(keyCode: DirectorKeyCode.up)
            runtime.stepFrame()
        }
        runtime.handleKeyUp(keyCode: DirectorKeyCode.up)
        check(abs(runtime.gameState.gSpeed - 99.0) < 1e-3 && runtime.gameState.gAfstand > 30.0, String(format: "FreeDrive Up arrow accelerated shuttle to gSpeedMax=%.1f (afstand=%.2fm)", runtime.gameState.gSpeed, runtime.gameState.gAfstand))

        // Test Braking (Spacebar 49) & Leo car-sickness bonus
        runtime.gameState.gSpeed = 700.0
        runtime.gameState.gRemIn = 14
        runtime.gameState.gSick = 25.0
        let scoreBeforeSick = runtime.gameState.gScore
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        runtime.stepFrame()
        runtime.handleKeyUp(keyCode: DirectorKeyCode.space, characters: " ")
        check(runtime.gameState.gSick == 26.0 && runtime.gameState.gScore == scoreBeforeSick + 1500, "Braking (Rem) for 15 frames triggers Leo car-sickness callout and +1500 bonus at gSick=26")

        // Test Booster Zone approach (Frame 20 -> 21), Left-arrow capture (3 boosters -> +700 bonus), and Right-arrow activation across all gears up to 799
        runtime.customRandomGenerator = { maxVal in
            if maxVal == 100 { return 10 } // 2..35 triggers Booster zone (Frame 20)
            return 1
        }
        for round in 1...3 {
            // Advance timer past CapLock (100 ticks)
            runtime.theTimer += 120
            runtime.gameState.gSpeed = 99.0
            runtime.gameState.gCounter = 15.0 // trigger EventCheck -> go(20)
            runtime.stepFrame() // transitions to Frame 20
            while runtime.currentFrame == 20 {
                runtime.handleKeyDown(keyCode: DirectorKeyCode.up)
                runtime.stepFrame()
            }
            runtime.handleKeyUp(keyCode: DirectorKeyCode.up)
            if runtime.currentFrame == 21 {
                runtime.stepFrame() // sets gBoReady = 1 in Frame 21 exitFrame
                runtime.handleKeyUp(keyCode: DirectorKeyCode.left) // keyUp(123) -> BoCapture() -> go(10)
            }
            check(runtime.gameState.gBoAmount == round && runtime.currentFrame == 10, "Captured Booster #\(round) inside Frame 21 (gBoAmount=\(runtime.gameState.gBoAmount), score=\(runtime.gameState.gScore))")
        }

        // Activate boosters with Right arrow (124) and verify gear progression up to gSpeedMax = 799
        for _ in 1...3 {
            runtime.handleKeyUp(keyCode: DirectorKeyCode.right)
        }
        check(abs(runtime.gameState.gSpeedMax - 399.0) < 1e-3 && runtime.gameState.gBoAmount == 0, "Activated 3 boosters via Right arrow raising gSpeedMax to \(runtime.gameState.gSpeedMax)")

        // Test reaching max speed 799 (+1000 bonus from Evelien)
        runtime.gameState.gBoAmount = 3
        runtime.gameState.gSpeedMax = 499.0
        for _ in 1...3 {
            runtime.handleKeyUp(keyCode: DirectorKeyCode.right)
        }
        check(abs(runtime.gameState.gSpeedMax - 799.0) < 1e-3, "Activating boosters up to 799 triggers Evelien heboostermax.hrs and +1000 score (gSpeed=\(runtime.gameState.gSpeed), gSpeedMax=\(runtime.gameState.gSpeedMax), score=\(runtime.gameState.gScore))")

        // Accelerate into Gear 5 and verify ShiftCheck / ShiftDwn downshift when gBoTimer expires
        runtime.gameState.gSpeed = 750.0
        runtime.gameState.gBoTimer = 2
        runtime.stepFrame() // gBoTimer -> 1 -> gSpeedMax drops from 799 to 699
        runtime.stepFrame() // ShiftDwn sees gSpeed (747) > gSpeedMax (699) -> sets gKeyLock = 1 and decelerates
        check(abs(runtime.gameState.gSpeedMax - 699.0) < 1e-3 && runtime.gameState.gKeyLock == 1, "ShiftCheck & ShiftDwn downshift gSpeedMax to 699 and engage gKeyLock=1 while speed decelerates")

        runtime.customRandomGenerator = nil

        // Test 1000m CheckPoint & 3-minute Game Over sequence (theTimer >= 10800 -> Frame 50..56 -> score.dir)
        runtime.gameState.gAfstand = 1050.0
        runtime.gameState.gAfstandtemp1 = 0.0
        runtime.gameCheckPoint()
        check(runtime.gameState.gAfstandtemp1 == 1050.0 && runtime.gameState.gMusicIndex >= 4.0, "CheckPoint at 1000m awards +400 points, advances gMusicIndex, and triggers Evelien distance callout")

        let finalGameScore = 8100
        runtime.gameState.gScore = finalGameScore
        runtime.theTimer = 10800
        runtime.stepFrame() // TimeAder() -> go(50)
        check(runtime.currentFrame == 50, "Reaching 3 minutes (the timer >= 10800) transitions to Game Over Frame 50")

        while runtime.currentMovie == .game {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .score && runtime.currentFrame == 1 && runtime.highScoreStore.readSData() == "8100", "Game Over sequence played gameover.hrs, faded audio, wrote '8100' to Xtras/sdata, and transitioned to score.dir")

        // -------------------------------------------------------------------------
        // 5. ScoreMovie (score.dxr) - Spoken Score, High Score Check & Name Entry
        // -------------------------------------------------------------------------
        print("\n--- 5. ScoreMovie (score.dxr) ---")
        // Ensure default high score (53700 by sander) is active before testing
        runtime.highScoreStore.saveHighScore(.defaultRecord)
        runtime.loadMovie(.score, frame: 1)

        // Step to Frame 16 (5-second score readout wait)
        while runtime.currentMovie == .score && runtime.currentFrame < 16 {
            runtime.stepFrame()
        }
        check(runtime.scoreState.gScoreField2 == "8100" && runtime.scoreState.gDuizend == 8.0 && runtime.scoreState.gHonderd == 1.0, "ScoreMovie readFile() decomposed '8100' into gDuizend=8, gHonderd=1")
        let scoreAudioStats = engine.processBlocks(24)
        check(scoreAudioStats.rmsLeft > 0.01, String(format: "ScoreMovie CPS speaking Dutch score readout (RMS L=%.4f)", scoreAudioStats.rmsLeft))

        // Advance past Frame 16 -> 17 -> 48 -> 49 -> 50 (scorecheck: 8100 <= 53700 -> Frame 26 -> 30 -> 35 -> 36)
        while runtime.currentMovie == .score && runtime.currentFrame != 36 {
            runtime.stepFrame()
        }
        check(runtime.currentFrame == 36 && runtime.scoreState.gInvoer == 2, "Score 8100 <= High Score 53700 routed through Frame 30 (druktoets.hrs) to Frame 36 (gInvoer=2 wait)")

        // Press Spacebar to exit ScoreMovie -> Frame 40 -> 42 music fade -> MenuMovie
        runtime.handleKeyDown(keyCode: DirectorKeyCode.space, characters: " ")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.space, characters: " ")
        while runtime.currentMovie == .score {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .menu && runtime.currentFrame == 1, "Pressing any key in gInvoer=2 fades music at Frame 42 and returns to menu.dir")

        // Now test BEATING the high score (e.g. 55200 > 53700) and typing a name in gInvoer=1!
        runtime.highScoreStore.writeSData("55200")
        runtime.loadMovie(.score, frame: 1)
        while runtime.currentMovie == .score && (runtime.currentFrame != 57 || runtime.scoreState.gInvoer != 1) {
            runtime.stepFrame()
        }
        check(runtime.currentFrame == 57 && runtime.scoreState.gInvoer == 1 && runtime.scoreState.gDuizend == 55.0 && runtime.scoreState.gHonderd == 2.0, "New High Score (55200 > 53700) played hiscore.hrs + naam.hrs and entered typnaamloop at Frame 57 (gInvoer=1)")

        // Type "alex", Backspace, "x", then Return (36)
        for ch in ["a", "l", "e", "z"] {
            runtime.handleKeyDown(keyCode: 0, characters: ch)
            runtime.handleKeyUp(keyCode: 0, characters: ch)
        }
        runtime.handleKeyDown(keyCode: DirectorKeyCode.backspace, characters: "")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.backspace, characters: "")
        runtime.handleKeyDown(keyCode: 0, characters: "x")
        runtime.handleKeyUp(keyCode: 0, characters: "x")
        check(runtime.scoreState.gNameField2 == "alex", "Typed high-score holder name 'alex' with Backspace editing in gInvoer=1")

        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        while runtime.currentMovie == .score && runtime.currentFrame != 36 {
            runtime.stepFrame()
        }
        let savedRecord = runtime.highScoreStore.loadHighScore()
        check(savedRecord.score == 55200 && savedRecord.name == "alex" && runtime.currentFrame == 36, "Pressing Enter saved new high score (55200 by 'alex') to Xtras/hiscore.json and returned to Frame 36")

        // Restore default high score and sdata so shipped bundle starts clean
        runtime.highScoreStore.saveHighScore(.defaultRecord)
        runtime.highScoreStore.writeSData("8100")

        // -------------------------------------------------------------------------
        // 6. Menu Confirm Quit -> QuitMovie (quit.dxr) -> Clean Exit
        // -------------------------------------------------------------------------
        print("\n--- 6. QuitMovie (quit.dxr) ---")
        runtime.loadMovie(.menu, frame: 1)
        while runtime.currentMovie == .menu && runtime.currentFrame < 13 {
            runtime.stepFrame()
        }
        runtime.menuState.menuCounter = 4
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 13 -> 80
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        runtime.stepFrame() // Frame 80 -> 81
        runtime.handleKeyDown(keyCode: DirectorKeyCode.returnKey, characters: "\r") // confirm quit -> 85
        runtime.handleKeyUp(keyCode: DirectorKeyCode.returnKey, characters: "\r")
        while runtime.currentMovie == .menu {
            runtime.stepFrame()
        }
        check(runtime.currentMovie == .quit && runtime.currentFrame == 1, "Confirming Quit in MenuMovie plays eve11, fades music at Frame 110, and transitions to quit.dir")

        while runtime.currentMovie == .quit && runtime.currentFrame < 9 {
            runtime.stepFrame()
        }
        let quitAudioStats = engine.processBlocks(16)
        check(runtime.currentFrame == 9 && quitAudioStats.rmsLeft > 0.01, String(format: "QuitMovie Frame 9 playing quit\\quitmix.hrs stereo audio (RMS L=%.4f R=%.4f)", quitAudioStats.rmsLeft, quitAudioStats.rmsRight))

        while !runtime.didQuit {
            runtime.stepFrame()
        }
        check(runtime.didQuit && !engine.isAudioRunning, "QuitMovie 22-second timer (1320 ticks) stopped audio and triggered clean application exit")

        print("\n================================================================================")
        print("VERIFICATION SUMMARY: \(passedCount) passed, \(failedCount) failed")
        print("================================================================================")
        return failedCount == 0
    }
}
