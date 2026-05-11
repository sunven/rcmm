import Foundation

public enum NotificationNames {
    public static var configChanged: String {
        "\(RuntimeConfiguration.notificationPrefix).configChanged"
    }

    public static var scriptUpdated: String {
        "\(RuntimeConfiguration.notificationPrefix).scriptUpdated"
    }
}
