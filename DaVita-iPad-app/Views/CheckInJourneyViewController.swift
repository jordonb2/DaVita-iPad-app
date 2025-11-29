import UIKit

final class CheckInJourneyViewController: ScrolledStackViewController, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {

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

    private let surveyHeaderLabel = UILabel()
    private let closeLabel = UILabel()

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
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "checkIn.cancel"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(submitTapped))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "checkIn.submit"

        buildContent()
        configureSurveyControls()

        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        surveyStartDate = Date()
    }
    override var stackSpacing: CGFloat { UIFactory.Theme.Spacing.xl }

    private func buildContent() {
        surveyHeaderLabel.text = "How are you today?"
        surveyHeaderLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        surveyHeaderLabel.numberOfLines = 0
        surveyHeaderLabel.accessibilityTraits.insert(.header)
        contentStackView.addArrangedSubview(surveyHeaderLabel)

        contentStackView.addArrangedSubview(makePainSection())
        contentStackView.addArrangedSubview(makeEnergySection())
        contentStackView.addArrangedSubview(makeMoodSection())
        contentStackView.addArrangedSubview(UIFactory.textEntrySection(title: "Symptoms", textView: symptomsTextView, placeholder: "Any symptoms today?") )
        contentStackView.addArrangedSubview(UIFactory.textEntrySection(title: "Concerns", textView: concernsTextView, placeholder: "Any concerns you want to share?") )

        let teamNoteHeader = UIFactory.sectionHeader(text: "Anything you want the team to know?")
        teamNoteHeader.accessibilityTraits.insert(.header)
        contentStackView.addArrangedSubview(teamNoteHeader)
        contentStackView.addArrangedSubview(UIFactory.textEntrySection(title: nil, textView: teamNoteTextView, placeholder: "Write a quick note...") )

        closeLabel.numberOfLines = 0
        closeLabel.textAlignment = .center
        closeLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        closeLabel.textColor = UIFactory.Theme.Color.textSecondary
        closeLabel.text = "Thanks for your response, your care team will review this before your session."
        closeLabel.isAccessibilityElement = true
        closeLabel.accessibilityLabel = closeLabel.text
        contentStackView.addArrangedSubview(closeLabel)
    }

    private func configureSurveyControls() {
        painSlider.minimumValue = 0
        painSlider.maximumValue = 10
        painSlider.value = 0
        painSlider.addTarget(self, action: #selector(painSliderChanged(_:)), for: .valueChanged)
        painSlider.accessibilityIdentifier = "checkIn.pain"

        energySegmentedControl.addTarget(self, action: #selector(energyChanged(_:)), for: .valueChanged)
        energySegmentedControl.accessibilityIdentifier = "checkIn.energy"
        moodSegmentedControl.addTarget(self, action: #selector(moodChanged(_:)), for: .valueChanged)
        moodSegmentedControl.accessibilityIdentifier = "checkIn.mood"

        painValueLabel.text = "0"
        painValueLabel.font = UIFont.preferredFont(forTextStyle: .body)
        painValueLabel.textAlignment = .right
        painValueLabel.isAccessibilityElement = false

        energySegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        moodSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment

        UIFactory.styleTextViewForForm(symptomsTextView)
        symptomsTextView.accessibilityIdentifier = "checkIn.symptoms"
        UIFactory.styleTextViewForForm(concernsTextView)
        concernsTextView.accessibilityIdentifier = "checkIn.concerns"
        UIFactory.styleTextViewForForm(teamNoteTextView)
        teamNoteTextView.accessibilityIdentifier = "checkIn.teamNote"

        painSlider.isAccessibilityElement = true
        painSlider.accessibilityLabel = "Pain level"
        painSlider.accessibilityTraits.insert(.adjustable)
        painSlider.accessibilityHint = "Swipe up or down to adjust pain from 0 to 10."
        updatePainAccessibilityValue()

        energySegmentedControl.isAccessibilityElement = true
        energySegmentedControl.accessibilityLabel = "Energy level"
        energySegmentedControl.accessibilityHint = "Select your energy today."

        moodSegmentedControl.isAccessibilityElement = true
        moodSegmentedControl.accessibilityLabel = "Mood"
        moodSegmentedControl.accessibilityHint = "Select your mood today."
    }

    private func makePainSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = UIFactory.Theme.Spacing.s

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        let titleLabel = UILabel()
        titleLabel.text = "Pain"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.isAccessibilityElement = false

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(painValueLabel)

        container.addArrangedSubview(titleRow)
        container.addArrangedSubview(painSlider)

        return container
    }

    private func makeEnergySection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = UIFactory.Theme.Spacing.s

        let titleLabel = UILabel()
        titleLabel.text = "Energy"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.isAccessibilityElement = false

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(energySegmentedControl)
        return container
    }

    private func makeMoodSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = UIFactory.Theme.Spacing.s

        let titleLabel = UILabel()
        titleLabel.text = "Mood"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.isAccessibilityElement = false

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(moodSegmentedControl)
        return container
    }

    @objc private func painSliderChanged(_ sender: UISlider) {
        let roundedValue = Int(sender.value.rounded())
        sender.value = Float(roundedValue)
        painValueLabel.text = "\(roundedValue)"
        updatePainAccessibilityValue()

        if !hasInteractedWithPain {
            hasInteractedWithPain = true
            lastInteractedStep = .pain
            analyticsLogger.logStepFirstInteracted(step: .pain)
        }
    }

    private func updatePainAccessibilityValue() {
        let value = Int(painSlider.value)
        painSlider.accessibilityValue = "\(value) out of 10"
    }

    @objc private func energyChanged(_ sender: UISegmentedControl) {
        if !hasInteractedWithEnergy {
            hasInteractedWithEnergy = true
            lastInteractedStep = .energy
            analyticsLogger.logStepFirstInteracted(step: .energy)
        }
        if sender.selectedSegmentIndex != UISegmentedControl.noSegment {
            let selectedTitle = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? ""
            sender.accessibilityValue = selectedTitle
        }
    }

    @objc private func moodChanged(_ sender: UISegmentedControl) {
        if !hasInteractedWithMood {
            hasInteractedWithMood = true
            lastInteractedStep = .mood
            analyticsLogger.logStepFirstInteracted(step: .mood)
        }
        if sender.selectedSegmentIndex != UISegmentedControl.noSegment {
            let selectedTitle = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? ""
            sender.accessibilityValue = selectedTitle
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
        let energyBucket: EnergyBucket? = energySegmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment ? nil : EnergyBucket(rawValue: Int16(energySegmentedControl.selectedSegmentIndex))
        let moodBucket: MoodBucket? = moodSegmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment ? nil : MoodBucket(rawValue: Int16(moodSegmentedControl.selectedSegmentIndex))

        let data = PersonCheckInData(
            painLevel: painLevel,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
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
