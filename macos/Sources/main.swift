import AppKit
import Foundation

func resolveDrivePaths() -> (xtrasURL: URL, picsURL: URL, patchesJSONURL: URL) {
    let fm = FileManager.default
    let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let macosDir = execURL.deletingLastPathComponent()
    let contentsDir = macosDir.deletingLastPathComponent()
    let resourcesDir = contentsDir.appendingPathComponent("Resources")
    let appBundleDir = contentsDir.deletingLastPathComponent()
    let bundleParentDir = appBundleDir.deletingLastPathComponent()
    let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath)

    // Candidate roots containing Xtras/ and pics/
    var rootCandidates: [URL] = [
        resourcesDir,
        bundleParentDir,
        cwdURL,
        cwdURL.deletingLastPathComponent()
    ]
    if let bundleRes = Bundle.main.resourceURL {
        rootCandidates.insert(bundleRes, at: 0)
    }

    var resolvedXtras = resourcesDir.appendingPathComponent("Xtras")
    var resolvedPics = resourcesDir.appendingPathComponent("pics")

    for root in rootCandidates {
        let xCandidate = root.appendingPathComponent("Xtras")
        let pCandidate = root.appendingPathComponent("pics")
        if fm.fileExists(atPath: xCandidate.path) && fm.fileExists(atPath: pCandidate.path) {
            resolvedXtras = xCandidate.resolvingSymlinksInPath()
            resolvedPics = pCandidate.resolvingSymlinksInPath()
            break
        }
    }

    var patchCandidates: [URL] = [
        resourcesDir.appendingPathComponent("cps_patches.json"),
        bundleParentDir.appendingPathComponent("macos/Resources/cps_patches.json"),
        cwdURL.appendingPathComponent("macos/Resources/cps_patches.json")
    ]
    if let bundleRes = Bundle.main.resourceURL {
        patchCandidates.insert(bundleRes.appendingPathComponent("cps_patches.json"), at: 0)
    }

    var resolvedPatches = resourcesDir.appendingPathComponent("cps_patches.json")
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
