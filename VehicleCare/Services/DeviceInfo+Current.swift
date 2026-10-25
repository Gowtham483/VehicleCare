import UIKit

extension DeviceInfo {
    static var current: DeviceInfo {
        var system = utsname()
        uname(&system)
        let model = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        let info = Bundle.main.infoDictionary
        return DeviceInfo(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: model)
    }
}
