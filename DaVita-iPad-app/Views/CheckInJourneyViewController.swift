import UIKit

final class CheckInJourneyViewController: ScrolledStackViewController, UITextViewDelegate, UIAdaptivePresentationControllerDelegate {

    var onComplete: ((PersonCheckInData) -> Void)?
    var onSkip: (() -> Void)?

    private let analyticsLogger: CheckInAnalyticsLogging
    private let guidanceProvider: SymptomGuidanceProviding?
    private var surveyStartDate: Date?
    private var hasInteractedWithPain = false
    private var hasInteractedWithEnergy = false
    private var hasInteractedWithMood = false
    private var hasInteractedWithSymptoms = false
    private var hasInteractedWithConcerns = false
    private var hasInteractedWithTeamNote = false
    private var lastInteractedStep: CheckInAnalyticsStep?

    init(analyticsLogger: CheckInAnalyticsLogging,
         guidanceProvider: SymptomGuidanceProviding? = nil) {
        self.analyticsLogger = analyticsLogger
        self.guidanceProvider = guidanceProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        title = "Optional Check-In"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "checkIn.cancel"

        let safety = UIBarButtonItem(title: "Need help now?", style: .plain, target: self, action: #selector(safetyTapped))
        safety.accessibilityIdentifier = "checkIn.safety"
        safety.accessibilityHint = "Opens an emergency action plan and contact options."

        let submit = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(submitTapped))
        submit.accessibilityIdentifier = "checkIn.submit"

        navigationItem.rightBarButtonItems = [submit, safety]

        buildContent()
        configureSurveyControls()
        configureFocusOrder()

        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        surveyStartDate = Date()
    }
    override var stackSpacing: CGFloat { UIFactory.Theme.Spacing.xl }

    private func buildContent() {
        resetContentStack()
        surveyHeaderLabel.text = "How are you today?"
        surveyHeaderLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        surveyHeaderLabel.adjustsFontForContentSizeCategory = true
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
        closeLabel.adjustsFontForContentSizeCategory = true
        closeLabel.textColor = UIFactory.Theme.Color.textSecondary
        closeLabel.text = "Thanks for your response, your care team will review this before your session."
        closeLabel.isAccessibilityElement = true
        closeLabel.accessibilityLabel = closeLabel.text
        contentStackView.addArrangedSubview(closeLabel)
    }

    private func configureSurveyControls() {
        painSlider.minimumValue = Float(ValidationRules.CheckIn.painMin)
        painSlider.maximumValue = Float(ValidationRules.CheckIn.painMax)
        painSlider.value = 0
        painSlider.addTarget(self, action: #selector(painSliderChanged(_:)), for: .valueChanged)
        painSlider.accessibilityIdentifier = "checkIn.pain"

        energySegmentedControl.addTarget(self, action: #selector(energyChanged(_:)), for: .valueChanged)
        energySegmentedControl.accessibilityIdentifier = "checkIn.energy"
        moodSegmentedControl.addTarget(self, action: #selector(moodChanged(_:)), for: .valueChanged)
        moodSegmentedControl.accessibilityIdentifier = "checkIn.mood"

        painValueLabel.text = "0"
        painValueLabel.font = UIFont.preferredFont(forTextStyle: .body)
        painValueLabel.adjustsFontForContentSizeCategory = true
        painValueLabel.textAlignment = .right
        painValueLabel.isAccessibilityElement = false

        energySegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        moodSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment

        UIFactory.styleTextViewForForm(symptomsTextView)
        symptomsTextView.delegate = self
        symptomsTextView.accessibilityIdentifier = "checkIn.symptoms"
        UIFactory.styleTextViewForForm(concernsTextView)
        concernsTextView.delegate = self
        concernsTextView.accessibilityIdentifier = "checkIn.concerns"
        UIFactory.styleTextViewForForm(teamNoteTextView)
        teamNoteTextView.delegate = self
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

    private func configureFocusOrder() {
        // Provide a stable, meaningful VoiceOver traversal order for this multi-control form.
        accessibilityElements = [
            surveyHeaderLabel,
            painSlider,
            energySegmentedControl,
            moodSegmentedControl,
            symptomsTextView,
            concernsTextView,
            teamNoteTextView,
            closeLabel
        ]
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
        titleLabel.adjustsFontForContentSizeCategory = true
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
        titleLabel.adjustsFontForContentSizeCategory = true
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
        titleLabel.adjustsFontForContentSizeCategory = true
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
        painSlider.accessibilityValue = "\(value) out of \(ValidationRules.CheckIn.painMax)"
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

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Allow IME composition (marked text) without enforcing hard limits mid-composition.
        if textView.markedTextRange != nil { return true }

        let maxChars: Int? = {
            if textView === symptomsTextView { return ValidationRules.CheckIn.maxSymptomsChars }
            if textView === concernsTextView { return ValidationRules.CheckIn.maxConcernsChars }
            if textView === teamNoteTextView { return ValidationRules.CheckIn.maxTeamNoteChars }
            return nil
        }()
        guard let maxChars else { return true }

        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        let next = current.replacingCharacters(in: r, with: text)
        return next.count <= maxChars
    }

    @objc private func safetyTapped() {
        let message = """
If this is a medical emergency, call 911 immediately.

Action plan:
• Pause and take slow breaths.
• Sit or lie down safely.
• Contact your care team as soon as possible.
"""
        let alert = UIAlertController(title: "Need help now?", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Call 911", style: .destructive) { _ in
            if let url = URL(string: "tel://911"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
        present(alert, animated: true)
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

        presentGuidanceIfNeeded(for: data) { [weak self] in
            self?.onComplete?(data)
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let durationSeconds = surveyDurationSeconds
        analyticsLogger.logDismissed(durationSeconds: durationSeconds, lastStep: lastInteractedStep)
    }

    private var surveyDurationSeconds: Double? {
        guard let surveyStartDate else { return nil }
        return Date().timeIntervalSince(surveyStartDate)
    }

    private func presentGuidanceIfNeeded(for data: PersonCheckInData, completion: @escaping () -> Void) {
        guard let guidanceProvider else {
            completion()
            return
        }

        let symptomCategories = TextCategorizer.categorizeSymptoms(from: data.symptoms)
        let concernCategories = TextCategorizer.categorizeConcerns(from: data.concerns)
        let tips = guidanceProvider.tips(forSymptoms: symptomCategories, concerns: concernCategories)

        guard !tips.isEmpty else {
            completion()
            return
        }

        let message = tips.prefix(3)
            .map { "• \($0.title)\n\($0.body)" }
            .joined(separator: "\n\n")
        let alert = UIAlertController(
            title: "Self-care tips",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
}
