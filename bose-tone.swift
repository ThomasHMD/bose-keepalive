// bose-tone : génère en continu une sinusoïde, sans jamais s'interrompre.
// Sans nom de carte, il joue sur la sortie par défaut du système ; avec un nom, il joue
// directement sur cette carte son et nulle part ailleurs. Jouer directement sur la carte
// évite les claquements : un logiciel de routage audio placé comme sortie par défaut
// (Background Music, Loopback…) rattrape régulièrement l'écart d'horloge avec la carte réelle,
// ce qui s'entend sur une sinusoïde pure. Deux autres claquements évités : relancer un fichier
// son en boucle (afplay) coupe la sortie à chaque tour.
// Fondu d'une seconde à l'allumage, d'une demi-seconde à l'arrêt (SIGTERM, envoyé par
// launchctl bootout). Si la configuration audio change, le son est relancé (chaque relance est
// notée sur la sortie d'erreur). Carte nommée absente : attend 30 s et s'arrête (launchd réessaie),
// rien n'est joué ailleurs.
//
// Usage : bose-tone <fréquence Hz> <niveau dBFS> [carte]   ex. bose-tone 20 -30 "Scarlett 2i2 USB"
// Compilé par bose-keepalive.sh : swiftc -O -swift-version 5 bose-tone.swift -o bose-tone
import AVFoundation
import CoreAudio
import Foundation

let args = CommandLine.arguments
let freq = args.count > 1 ? Double(args[1]) ?? 20 : 20
let dB = args.count > 2 ? Double(args[2]) ?? -30 : -30
let amp = Float(pow(10.0, dB / 20.0))
let carte = args.count > 3 ? args[3] : ""          // vide = sortie par défaut du système
let nomCarte = carte.isEmpty ? "la sortie par défaut" : "« \(carte) »"

func erreur(_ m: String) { FileHandle.standardError.write("bose-tone : \(m)\n".data(using: .utf8)!) }

// Sortie par défaut du système.
func sortieParDefaut() -> AudioDeviceID? {
    var adr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                         mScope: kAudioObjectPropertyScopeGlobal,
                                         mElement: kAudioObjectPropertyElementMain)
    var id = AudioDeviceID(0)
    var t = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &adr, 0, nil, &t, &id) == noErr,
          id != kAudioObjectUnknown else { return nil }
    return id
}

// Carte de sortie par son nom (celui de Réglages Système > Son).
func sortie(nommee nom: String) -> AudioDeviceID? {
    let systeme = AudioObjectID(kAudioObjectSystemObject)
    var adr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                         mScope: kAudioObjectPropertyScopeGlobal,
                                         mElement: kAudioObjectPropertyElementMain)
    var taille: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(systeme, &adr, 0, nil, &taille) == noErr else { return nil }
    var ids = [AudioDeviceID](repeating: 0, count: Int(taille) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(systeme, &adr, 0, nil, &taille, &ids) == noErr else { return nil }
    for id in ids {
        var adrNom = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var cf: Unmanaged<CFString>?
        var t = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &adrNom, 0, nil, &t, &cf) == noErr,
              let n = cf?.takeRetainedValue() as String?, n == nom else { continue }
        var adrFlux = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: kAudioObjectPropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var tf: UInt32 = 0
        if AudioObjectGetPropertyDataSize(id, &adrFlux, 0, nil, &tf) == noErr, tf > 0 { return id }
    }
    return nil
}

// La cible : la carte nommée, ou la sortie par défaut si aucun nom n'est donné.
func cible_carte() -> AudioDeviceID? { carte.isEmpty ? sortieParDefaut() : sortie(nommee: carte) }

guard var idCarte = cible_carte() else {
    erreur("\(nomCarte) introuvable, nouvel essai dans 30 s")
    sleep(30); exit(1)
}

let engine = AVAudioEngine()
guard AudioUnitSetProperty(engine.outputNode.audioUnit!, kAudioOutputUnitProperty_CurrentDevice,
                           kAudioUnitScope_Global, 0, &idCarte,
                           UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr else {
    erreur("impossible de sortir sur \(nomCarte)"); sleep(30); exit(1)
}
let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
let step = 2 * Double.pi * freq / sampleRate
var phase = 0.0
var gain: Float = 0          // enveloppe du fondu
var cible: Float = 1         // 1 = en marche, 0 = extinction en cours
let pasMontee = Float(1.0 / sampleRate)          // 1 s
let pasDescente = Float(2.0 / sampleRate)        // 0,5 s

let source = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    for i in 0..<Int(frameCount) {
        if gain < cible { gain = min(cible, gain + pasMontee) }
        else if gain > cible { gain = max(cible, gain - pasDescente) }
        let v = amp * gain * Float(sin(phase))
        phase += step
        if phase >= 2 * Double.pi { phase -= 2 * Double.pi }
        for b in buffers { b.mData!.assumingMemoryBound(to: Float.self)[i] = v }
    }
    return noErr
}

let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
engine.attach(source)
engine.connect(source, to: engine.mainMixerNode, format: mono)

// Changement de configuration : AVAudioEngine s'arrête tout seul (c'est le cas juste après
// le choix de la carte). On le relance sur la même carte (ou sur la nouvelle sortie par défaut
// si aucun nom n'a été donné) ; si la carte a disparu ou changé
// de fréquence d'échantillonnage, on s'arrête et launchd relance proprement.
func carteActuelle() -> AudioDeviceID {
    var id = AudioDeviceID(0); var t = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioUnitGetProperty(engine.outputNode.audioUnit!, kAudioOutputUnitProperty_CurrentDevice,
                         kAudioUnitScope_Global, 0, &id, &t)
    return id
}
NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                       object: engine, queue: .main) { _ in
    guard var id = cible_carte() else { erreur("\(nomCarte) perdue"); exit(1) }
    if carteActuelle() != id {
        AudioUnitSetProperty(engine.outputNode.audioUnit!, kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
    }
    let taux = engine.outputNode.outputFormat(forBus: 0).sampleRate
    if taux != sampleRate { erreur("fréquence d'échantillonnage \(sampleRate) → \(taux), redémarrage"); exit(0) }
    erreur("\(Date()) changement de configuration audio, relance du son")
    do { try engine.start() } catch { erreur("relance impossible : \(error)"); exit(1) }
}

signal(SIGTERM, SIG_IGN)
let arret = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
arret.setEventHandler {
    cible = 0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { exit(0) }
}
arret.resume()

do { try engine.start() } catch {
    erreur("démarrage audio impossible : \(error)"); sleep(30); exit(1)
}
RunLoop.main.run()
