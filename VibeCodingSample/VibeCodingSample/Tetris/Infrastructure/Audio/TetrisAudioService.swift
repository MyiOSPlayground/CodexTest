import AppKit

protocol TetrisAudioService {
    func playStart()
    func playLock()
    func playLineClear()
    func playStageUp()
    func playGameOver()
    func playHardDrop()
}

final class SystemTetrisAudioService: TetrisAudioService {
    private var cache: [String: NSSound] = [:]

    func playStart() { play(named: "Ping") }
    func playLock() { play(named: "Pop") }
    func playLineClear() { play(named: "Glass") }
    func playStageUp() { play(named: "Hero") }
    func playGameOver() { play(named: "Basso") }
    func playHardDrop() { play(named: "Funk") }

    private func play(named name: String) {
        if let sound = sound(named: name) {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func sound(named name: String) -> NSSound? {
        if let cached = cache[name] {
            return cached
        }

        guard let sound = NSSound(named: NSSound.Name(name)) else {
            return nil
        }
        cache[name] = sound
        return sound
    }
}
