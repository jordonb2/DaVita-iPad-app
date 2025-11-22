import UIKit

final class CheckInJourneyViewController: UIViewController, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {

    var onComplete: ((PersonCheckInData) -> Void)?
    var onSkip: (() -> Void)?

    private let analyticsLogger = CheckInAnalyticsLogger.shared
    private var surveyStartDate: Date?
    private var hasInteractedWithPain = false
    private var hasInteractedWithEnergy = false
    private var hasInteractedWithMood = false
    private var hasInteractedWithSymptoms = false
    private var hasInteractedWithConcerns = false
    private var hasInteractedWithTeamNote = false
    private var lastInteractedStep: CheckInAnalyticsLogger.Step?

    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let painSlider = UISlider()
    private let painValueLabel = UILabel()

    private let energySegmentedControl = UISegmentedControl(items: ["Low", "Okay", "High"])
    private let moodSegmentedControl = UISegmentedControl(items: ["Sad", "Neutral", "Good"])

    private let symptomsTextView = UITextView()
    private let concernsTextView = UITextView()
    private let teamNoteTextView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Optional Check-In Survey"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(submitTapped))

        configureLayout()
        configureSurveyControls()

        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        surveyStartDate = Date()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        ])

        let headerLabel = makeSectionHeader(text: "How are you today?")
        contentStackView.addArrangedSubview(headerLabel)

        contentStackView.addArrangedSubview(makePainSection())
        contentStackView.addArrangedSubview(makeEnergySection())
        contentStackView.addArrangedSubview(makeMoodSection())
        contentStackView.addArrangedSubview(makeTextSection(title: "Symptoms", textView: symptomsTextView, placeholder: "Any symptoms today?") )
        contentStackView.addArrangedSubview(makeTextSection(title: "Concerns", textView: concernsTextView, placeholder: "Any concerns you want to share?") )

        let teamNoteHeader = makeSectionHeader(text: "Anything you want the team to know?")
        contentStackView.addArrangedSubview(teamNoteHeader)
        contentStackView.addArrangedSubview(makeTextSection(title: nil, textView: teamNoteTextView, placeholder: "Write a quick note...") )

        let closeLabel = UILabel()
        closeLabel.numberOfLines = 0
        closeLabel.textAlignment = .center
        closeLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        closeLabel.textColor = .secondaryLabel
        closeLabel.text = "Thanks for your response, your care team will review this before your session."
        contentStackView.addArrangedSubview(closeLabel)
    }

    private func configureSurveyControls() {
        painSlider.minimumValue = 0
        painSlider.maximumValue = 10
        painSlider.value = 0
        painSlider.addTarget(self, action: #selector(painSliderChanged(_:)), for: .valueChanged)

        energySegmentedControl.addTarget(self, action: #selector(energyChanged(_:)), for: .valueChanged)
        moodSegmentedControl.addTarget(self, action: #selector(moodChanged(_:)), for: .valueChanged)

        painValueLabel.text = "0"
        painValueLabel.font = UIFont.preferredFont(forTextStyle: .body)
        painValueLabel.textAlignment = .right

        energySegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        moodSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment

        configureTextView(symptomsTextView)
        configureTextView(concernsTextView)
        configureTextView(teamNoteTextView)
    }

    private func configureTextView(_ textView: UITextView) {
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.cornerRadius = 8
        textView.isScrollEnabled = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        textView.delegate = self
    }

    private func makePainSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        let titleLabel = UILabel()
        titleLabel.text = "Pain"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(painValueLabel)

        container.addArrangedSubview(titleRow)
        container.addArrangedSubview(painSlider)

        return container
    }

    private func makeEnergySection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = "Energy"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(energySegmentedControl)
        return container
    }

    private func makeMoodSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = "Mood"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(moodSegmentedControl)
        return container
    }

    private func makeTextSection(title: String?, textView: UITextView, placeholder: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        if let title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            container.addArrangedSubview(titleLabel)
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        placeholderLabel.textColor = .secondaryLabel
        container.addArrangedSubview(placeholderLabel)
        container.addArrangedSubview(textView)

        return container
    }

    private func makeSectionHeader(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.numberOfLines = 0
        return label
    }

    @objc private func painSliderChanged(_ sender: UISlider) {
        let roundedValue = Int(sender.value.rounded())
        sender.value = Float(roundedValue)
        painValueLabel.text = "\(roundedValue)"

        if !hasInteractedWithPain {
            hasInteractedWithPain = true
            lastInteractedStep = .pain
            analyticsLogger.logStepFirstInteracted(step: .pain)
        }
    }

    @objc private func energyChanged(_ sender: UISegmentedControl) {
        if !hasInteractedWithEnergy {
            hasInteractedWithEnergy = true
            lastInteractedStep = .energy
            analyticsLogger.logStepFirstInteracted(step: .energy)
        }
    }

    @objc private func moodChanged(_ sender: UISegmentedControl) {
        if !hasInteractedWithMood {
            hasInteractedWithMood = true
            lastInteractedStep = .mood
            analyticsLogger.logStepFirstInteracted(step: .mood)
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView === symptomsTextView, !hasInteractedWithSymptoms {
            hasInteractedWithSymptoms = true
            lastInteractedStep = .symptoms
            analyticsLogger.logStepFirstInteracted(step: .symptoms)
        } else if textView === concernsTextView, !hasInteractedWithConcerns {
            hasInteractedWithConcerns = true
            lastInteractedStep = .concerns
            analyticsLogger.logStepFirstInteracted(step: .concerns)
        } else if textView === teamNoteTextView, !hasInteractedWithTeamNote {
            hasInteractedWithTeamNote = true
            lastInteractedStep = .teamNote
            analyticsLogger.logStepFirstInteracted(step: .teamNote)
        }
    }

    @objc private func cancelTapped() {
        let durationSeconds = surveyDurationSeconds
        analyticsLogger.logSkipped(durationSeconds: durationSeconds, lastStep: lastInteractedStep)
        onSkip?()
    }

    @objc private func submitTapped() {
        let painLevel = Int16(painSlider.value)
        let energyText = energySegmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment ? nil : energySegmentedControl.titleForSegment(at: energySegmentedControl.selectedSegmentIndex)
        let moodText = moodSegmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment ? nil : moodSegmentedControl.titleForSegment(at: moodSegmentedControl.selectedSegmentIndex)

        let data = PersonCheckInData(
            painLevel: painLevel,
            energyLevel: energyText,
            mood: moodText,
            symptoms: symptomsTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            concerns: concernsTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            teamNote: teamNoteTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let durationSeconds = surveyDurationSeconds ?? 0
        analyticsLogger.logSubmitted(checkInData: data, durationSeconds: durationSeconds)

        onComplete?(data)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let durationSeconds = surveyDurationSeconds
        analyticsLogger.logDismissed(durationSeconds: durationSeconds, lastStep: lastInteractedStep)
    }

    private var surveyDurationSeconds: Double? {
        guard let surveyStartDate else { return nil }
        return Date().timeIntervalSince(surveyStartDate)
    }
}
