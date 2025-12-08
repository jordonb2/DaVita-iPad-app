import UIKit

final class SmartRemindersViewController: ScrolledStackViewController {

    private let manager: SmartReminderManaging

    private lazy var dailySwitch: UISwitch = {
        let s = UISwitch()
        s.addTarget(self, action: #selector(dailyToggled(_:)), for: .valueChanged)
        return s
    }()

    private lazy var timePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.datePickerMode = .time
        p.preferredDatePickerStyle = .wheels
        p.addTarget(self, action: #selector(timeChanged(_:)), for: .valueChanged)
        return p
    }()

    private lazy var highPainSwitch: UISwitch = {
        let s = UISwitch()
        s.addTarget(self, action: #selector(highPainToggled(_:)), for: .valueChanged)
        return s
    }()

    private lazy var thresholdStepper: UIStepper = {
        let st = UIStepper()
        st.minimumValue = 1
        st.maximumValue = 10
        st.addTarget(self, action: #selector(thresholdChanged(_:)), for: .valueChanged)
        return st
    }()

    private let thresholdLabel = UILabel()

    init(manager: SmartReminderManaging) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Smart reminders"
        view.backgroundColor = UIFactory.Theme.Color.surface
        render()
        applySettingsToUI()
    }

    private func render() {
        resetContentStack()

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Treatment schedule", textStyle: .title2))

        let dailyRow = UIStackView()
        dailyRow.axis = .horizontal
        dailyRow.alignment = .center
        dailyRow.spacing = UIFactory.Theme.Spacing.m

        let dailyLabel = UILabel()
        dailyLabel.text = "Daily check-in reminder"
        dailyLabel.numberOfLines = 0
        dailyLabel.font = UIFactory.Theme.Font.preferred(.body)

        dailyRow.addArrangedSubview(dailyLabel)
        dailyRow.addArrangedSubview(dailySwitch)
        contentStackView.addArrangedSubview(dailyRow)

        let timeLabel = UILabel()
        timeLabel.text = "Reminder time"
        timeLabel.font = UIFactory.Theme.Font.preferred(.body)
        timeLabel.numberOfLines = 0

        let timeStack = UIFactory.verticalStack(spacing: UIFactory.Theme.Spacing.s)
        timeStack.addArrangedSubview(timeLabel)
        timeStack.addArrangedSubview(timePicker)
        contentStackView.addArrangedSubview(timeStack)

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "High pain nudges", textStyle: .title2))

        let highPainRow = UIStackView()
        highPainRow.axis = .horizontal
        highPainRow.alignment = .center
        highPainRow.spacing = UIFactory.Theme.Spacing.m

        let highPainLabel = UILabel()
        highPainLabel.text = "Send nudge after high pain"
        highPainLabel.numberOfLines = 0
        highPainLabel.font = UIFactory.Theme.Font.preferred(.body)

        highPainRow.addArrangedSubview(highPainLabel)
        highPainRow.addArrangedSubview(highPainSwitch)
        contentStackView.addArrangedSubview(highPainRow)

        thresholdLabel.font = UIFactory.Theme.Font.preferred(.body)
        thresholdLabel.numberOfLines = 0

        let thresholdStack = UIStackView()
        thresholdStack.axis = .horizontal
        thresholdStack.alignment = .center
        thresholdStack.spacing = UIFactory.Theme.Spacing.m
        thresholdStack.addArrangedSubview(thresholdLabel)
        thresholdStack.addArrangedSubview(thresholdStepper)

        contentStackView.addArrangedSubview(thresholdStack)
    }

    private func applySettingsToUI() {
        let settings = manager.currentSettings
        dailySwitch.isOn = settings.dailyEnabled
        highPainSwitch.isOn = settings.highPainEnabled
        thresholdStepper.value = Double(settings.highPainThreshold)
        thresholdLabel.text = "High pain threshold: \(settings.highPainThreshold)/10"

        if let comps = settings.dailyTime,
           let hour = comps.hour,
           let minute = comps.minute {
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            let date = Calendar.current.date(from: dc) ?? Date()
            timePicker.date = date
        }
    }

    @objc private func dailyToggled(_ sender: UISwitch) {
        manager.updateSettings({ settings in
            settings.dailyEnabled = sender.isOn
        }, completion: { _ in })
    }

    @objc private func timeChanged(_ sender: UIDatePicker) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: sender.date)
        manager.updateSettings({ settings in
            settings.dailyTime = comps
        }, completion: { _ in })
    }

    @objc private func highPainToggled(_ sender: UISwitch) {
        manager.updateSettings({ settings in
            settings.highPainEnabled = sender.isOn
        }, completion: { _ in })
    }

    @objc private func thresholdChanged(_ sender: UIStepper) {
        let value = Int(sender.value.rounded())
        thresholdLabel.text = "High pain threshold: \(value)/10"
        manager.updateSettings({ settings in
            settings.highPainThreshold = value
        }, completion: { _ in })
    }
}

