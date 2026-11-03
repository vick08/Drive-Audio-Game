import AppKit
import Foundation

func resolveDrivePaths() -> (xtrasURL: URL, picsURL: URL, patchesJSONURL: URL) {
    let fm = FileManager.default
    let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let macosDir = execURL.deletingLastPathComponent()
    let contentsDir = macosDir.deletingLastPathComponent()
    let appBundleDir = contentsDir.deletingLastPathComponent()
    let bundleParentDir = appBundleDir.deletingLastPathComponent()
    let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath)

    // Candidate roots containing Xtras/ and pics/
    let rootCandidates: [URL] = [
        bundleParentDir,
        contentsDir.appendingPathComponent("Resources"),
        cwdURL,
        cwdURL.deletingLastPathComponent(),
        URL(fileURLWithPath: "/Users/vtsaran/src/drive"),
    ]

    var resolvedXtras = URL(fileURLWithPath: "/Users/vtsaran/src/drive/Xtras")
    var resolvedPics = URL(fileURLWithPath: "/Users/vtsaran/src/drive/pics")

    for root in rootCandidates {
        let xCandidate = root.appendingPathComponent("Xtras")
        let pCandidate = root.appendingPathComponent("pics")
        if fm.fileExists(atPath: xCandidate.path) && fm.fileExists(atPath: pCandidate.path) {
            resolvedXtras = xCandidate.resolvingSymlinksInPath()
            resolvedPics = pCandidate.resolvingSymlinksInPath()
            break
        }
    }

    let patchCandidates: [URL] = [
        contentsDir.appendingPathComponent("Resources/cps_patches.json"),
        bundleParentDir.appendingPathComponent("macos/Resources/cps_patches.json"),
        cwdURL.appendingPathComponent("macos/Resources/cps_patches.json"),
        URL(fileURLWithPath: "/Users/vtsaran/src/drive/macos/Resources/cps_patches.json"),
    ]

    var resolvedPatches = URL(fileURLWithPath: "/Users/vtsaran/src/drive/macos/Resources/cps_patches.json")
    for candidate in patchCandidates {
        if fm.fileExists(atPath: candidate.path) {
            resolvedPatches = candidate
            break
        }
    }

    return (resolvedXtras, resolvedPics, resolvedPatches)
}

let paths = resolveDrivePaths()

if CommandLine.arguments.contains("--verify") {
    let ok = VerifySuite.runAll(
        xtrasURL: paths.xtrasURL,
        picsURL: paths.picsURL,
        patchesJSONURL: paths.patchesJSONURL
    )
    exit(ok ? 0 : 1)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let engine = CPSAudioEngine(xtrasURL: paths.xtrasURL, patchesJSONURL: paths.patchesJSONURL)
let runtime = DirectorRuntime(audioEngine: engine, xtrasURL: paths.xtrasURL, picsURL: paths.picsURL)
let delegate = DriveAppDelegate(runtime: runtime)
app.delegate = delegate
app.run()
