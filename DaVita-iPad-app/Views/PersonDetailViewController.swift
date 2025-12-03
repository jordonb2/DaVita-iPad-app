import UIKit

/// Simple detail screen for a person, with actions to edit or drill into history.
final class PersonDetailViewController: ScrolledStackViewController {

    private let person: Person

    var onEditTapped: ((Person) -> Void)?
    var onHistoryTapped: ((Person) -> Void)?
    var onTrendsTapped: ((Person) -> Void)?

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    init(person: Person) {
        self.person = person
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = person.name ?? "Person"
        view.backgroundColor = .systemBackground

        render()
        configureNavItems()
    }

    private func configureNavItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Edit person"
    }

    private func render() {
        resetContentStack()

        if person.managedObjectContext == nil || person.isDeleted {
            contentStackView.addArrangedSubview(
                StateView(model: .error(
                    title: "Person unavailable",
                    message: "This record is no longer available.",
                    actionTitle: "Go back",
                    onAction: { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                ))
            )
            return
        }

        let hasAnyDetail = (person.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ||
            person.dob != nil ||
            person.genderEnum != nil

        if !hasAnyDetail {
            contentStackView.addArrangedSubview(
                StateView(model: .empty(
                    title: "No details yet",
                    message: "Add details for this person to see them here.",
                    actionTitle: "Edit person",
                    onAction: { [weak self] in
                        guard let self else { return }
                        self.onEditTapped?(self.person)
                    }
                ))
            )
            return
        }

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Details"))

        let name = person.name ?? "—"
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Name", value: name))

        if let dob = person.dob {
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "DOB", value: Self.dobFormatter.string(from: dob)))
        } else {
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "DOB", value: "—"))
        }

        let gender = person.genderEnum?.displayText ?? "—"
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Gender", value: gender))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Actions", textStyle: .headline))

        let historyButton = UIFactory.roundedActionButton(title: "View Visit History")
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        historyButton.isAccessibilityElement = true
        historyButton.accessibilityLabel = "View visit history"
        historyButton.accessibilityHint = "Shows this person's past check-ins."
        contentStackView.addArrangedSubview(historyButton)

        let trendsButton = UIFactory.roundedActionButton(title: "View Trends")
        trendsButton.addTarget(self, action: #selector(trendsTapped), for: .touchUpInside)
        trendsButton.isAccessibilityElement = true
        trendsButton.accessibilityLabel = "View trends"
        trendsButton.accessibilityHint = "Shows pain trend, energy/mood distributions, and symptom frequency over time."
        contentStackView.addArrangedSubview(trendsButton)
    }

    @objc private func editTapped() {
        onEditTapped?(person)
    }

    @objc private func historyTapped() {
        onHistoryTapped?(person)
    }

    @objc private func trendsTapped() {
        onTrendsTapped?(person)
    }
}
