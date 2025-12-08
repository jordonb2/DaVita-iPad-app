import Foundation
import UserNotifications

protocol SmartReminderScheduling {
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void)
    func scheduleDaily(settings: SmartReminderSettings)
    func scheduleHighPainNudge()
    func cancelAll()
}

final class SmartReminderScheduler: NSObject, SmartReminderScheduling {
    private enum IDs {
        static let daily = "smartReminder.daily"
        static let highPain = "smartReminder.highPain"
    }

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
        super.init()
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func scheduleDaily(settings: SmartReminderSettings) {
        guard settings.dailyEnabled, let time = settings.dailyTime, let hour = time.hour, let minute = time.minute else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Check-in reminder"
        content.body = "Time to complete today’s check-in."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: IDs.daily, content: content, trigger: trigger)

        center.add(request, withCompletionHandler: nil)
    }

    func scheduleHighPainNudge() {
        let content = UNMutableNotificationContent()
        content.title = "How are you feeling?"
        content.body = "We noticed recent high pain. Take a moment to log a check-in."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 5, repeats: false)
        let request = UNNotificationRequest(identifier: IDs.highPain, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [IDs.daily, IDs.highPain])
    }
}

