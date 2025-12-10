import UIKit

final class AdminDigestSettingsViewController: ScrolledStackViewController {

    private let manager: AdminAlertsDigestManaging

    private lazy var cadenceControl: UISegmentedControl = {
        let control = UISegmentedControl(items: AdminDigestCadence.allCases.map { $0.displayName })
        control.addTarget(self, action: #selector(cadenceChanged(_:)), for: .valueChanged)
        return control
    }()

    private lazy var deliveryTimePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(self, action: #selector(timeChanged(_:)), for: .valueChanged)
        return picker
    }()

    private lazy var atRiskSwitch: UISwitch = {
        let s = UISwitch()
        s.addTarget(self, action: #selector(atRiskToggled(_:)), for: .valueChanged)
        return s
    }()

    private lazy var overdueSwitch: UISwitch = {
        let s = UISwitch()
        s.addTarget(self, action: #selector(overdueToggled(_:)), for: .valueChanged)
        return s
    }()

    private lazy var overdueStepper: UIStepper = {
        let st = UIStepper()
        st.minimumValue = 1
        st.maximumValue = 30
        st.addTarget(self, action: #selector(overdueChanged(_:)), for: .valueChanged)
        return st
    }()

    private let overdueLabel = UILabel()

    init(manager: AdminAlertsDigestManaging) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Admin alerts digest"
        view.backgroundColor = UIFactory.Theme.Color.surface
        render()
        applySettingsToUI()
    }

    private func render() {
        resetContentStack()

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Cadence", textStyle: .title2))
        contentStackView.addArrangedSubview(cadenceControl)

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Delivery time", textStyle: .title2))
        contentStackView.addArrangedSubview(deliveryTimePicker)

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Include in digest", textStyle: .title2))

        let atRiskRow = UIStackView()
        atRiskRow.axis = .horizontal
        atRiskRow.alignment = .center
        atRiskRow.spacing = UIFactory.Theme.Spacing.m
        let atRiskLabel = UILabel()
        atRiskLabel.text = "At-risk signals"
        atRiskLabel.numberOfLines = 0
        atRiskLabel.font = UIFactory.Theme.Font.preferred(.body)
        atRiskRow.addArrangedSubview(atRiskLabel)
        atRiskRow.addArrangedSubview(atRiskSwitch)
        contentStackView.addArrangedSubview(atRiskRow)

        let overdueRow = UIStackView()
        overdueRow.axis = .horizontal
        overdueRow.alignment = .center
        overdueRow.spacing = UIFactory.Theme.Spacing.m
        let overdueTitle = UILabel()
        overdueTitle.text = "Overdue follow-ups"
        overdueTitle.numberOfLines = 0
        overdueTitle.font = UIFactory.Theme.Font.preferred(.body)
        overdueRow.addArrangedSubview(overdueTitle)
        overdueRow.addArrangedSubview(overdueSwitch)
        contentStackView.addArrangedSubview(overdueRow)

        overdueLabel.font = UIFactory.Theme.Font.preferred(.body)
        overdueLabel.numberOfLines = 0

        let overdueStack = UIStackView()
        overdueStack.axis = .horizontal
        overdueStack.alignment = .center
        overdueStack.spacing = UIFactory.Theme.Spacing.m
        overdueStack.addArrangedSubview(overdueLabel)
        overdueStack.addArrangedSubview(overdueStepper)
        contentStackView.addArrangedSubview(overdueStack)
    }

    private func applySettingsToUI() {
        let settings = manager.currentSettings
        cadenceControl.selectedSegmentIndex = AdminDigestCadence.allCases.firstIndex(of: settings.cadence) ?? 0

        if let hour = settings.deliveryTime.hour, let minute = settings.deliveryTime.minute {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let date = Calendar.current.date(from: comps) ?? Date()
            deliveryTimePicker.date = date
        }

        atRiskSwitch.isOn = settings.includeAtRisk
        overdueSwitch.isOn = settings.includeOverdue

        overdueStepper.value = Double(settings.overdueDaysThreshold)
        overdueLabel.text = "Overdue after \(settings.overdueDaysThreshold) days"

        updateControlStates()
    }

    private func updateControlStates() {
        let enabled = manager.currentSettings.cadence != .off
        deliveryTimePicker.isEnabled = enabled
        atRiskSwitch.isEnabled = enabled
        overdueSwitch.isEnabled = enabled
        overdueStepper.isEnabled = enabled && manager.currentSettings.includeOverdue
    }

    private func updateSettings(_ mutate: @escaping (inout AdminDigestSettings) -> Void) {
        manager.updateSettings(mutate) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if !granted {
                    let alert = AlertFactory.okAlert(
                        title: "Notifications disabled",
                        message: "Enable notifications in Settings to get admin digests."
                    )
                    self.present(alert, animated: true)
                }
                self.applySettingsToUI()
            }
        }
    }

    @objc private func cadenceChanged(_ sender: UISegmentedControl) {
        guard sender.selectedSegmentIndex < AdminDigestCadence.allCases.count else { return }
        let cadence = AdminDigestCadence.allCases[sender.selectedSegmentIndex]
        updateSettings { settings in
            settings.cadence = cadence
        }
    }

    @objc private func timeChanged(_ sender: UIDatePicker) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: sender.date)
        updateSettings { settings in
            settings.deliveryTime = comps
        }
    }

    @objc private func atRiskToggled(_ sender: UISwitch) {
        updateSettings { settings in
            settings.includeAtRisk = sender.isOn
        }
    }

    @objc private func overdueToggled(_ sender: UISwitch) {
        updateSettings { settings in
            settings.includeOverdue = sender.isOn
        }
    }

    @objc private func overdueChanged(_ sender: UIStepper) {
        let value = max(1, Int(sender.value.rounded()))
        overdueLabel.text = "Overdue after \(value) days"
        updateSettings { settings in
            settings.overdueDaysThreshold = value
        }
    }
}


