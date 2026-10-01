import DeviceCheck

/// Jeton Apple DeviceCheck : permet au serveur de n'octroyer les crédits de bienvenue qu'UNE fois par iPhone,
/// même après réinstallation (utilisé seulement si les secrets DeviceCheck sont configurés côté serveur).
enum DeviceToken {
    static func current() async -> String? {
        guard DCDevice.current.isSupported else { return nil } // simulateur
        return try? await DCDevice.current.generateToken().base64EncodedString()
    }
}
