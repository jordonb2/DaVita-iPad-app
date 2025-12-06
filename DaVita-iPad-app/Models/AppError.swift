import Foundation

/// App-wide error model with consistent user-facing messaging.
enum AppError: Error {
    enum PresentationStyle {
        case toast
        case alert
    }

    struct UserFacingMessage {
        let title: String
        let message: String?
        let style: PresentationStyle
        let actionTitle: String?

        init(title: String, message: String?, style: PresentationStyle, actionTitle: String? = nil) {
            self.title = title
            self.message = message
            self.style = style
            self.actionTitle = actionTitle
        }
    }

    enum Operation {
        case loadPeople
        case savePerson
        case deletePerson

        case loadHistory
        case loadTrends
        case loadAnalytics

        case exportCSV
        case exportPDF
    }

    enum Validation {
        case emptyName
    }

    case operation(Operation, underlying: Error?)
    case validation(Validation)
    case authRequired
    case unknown(Error)

    init(operation: Operation, underlying: Error? = nil) {
        self = .operation(operation, underlying: underlying)
    }

    init(_ error: Error, defaultOperation: Operation) {
        if let appError = error as? AppError {
            self = appError
        } else {
            self = .operation(defaultOperation, underlying: error)
        }
    }

    var userFacing: UserFacingMessage {
        switch self {
        case .validation(let v):
            switch v {
            case .emptyName:
                return UserFacingMessage(
                    title: "Missing name",
                    message: "Please enter a name before saving.",
                    style: .toast
                )
            }

        case .authRequired:
            return UserFacingMessage(
                title: "Admin required",
                message: "Please log in as admin to continue.",
                style: .alert,
                actionTitle: "Log in"
            )

        case .operation(let op, let underlying):
            switch op {
            case .loadPeople:
                if isOffline(underlying) {
                    return offlineMessage(style: .toast)
                }
                return UserFacingMessage(
                    title: "Couldn't load people",
                    message: "Check your connection, then retry.",
                    style: .toast,
                    actionTitle: "Retry"
                )
            case .savePerson:
                return UserFacingMessage(
                    title: "Couldn't save",
                    message: "Please try again.",
                    style: .alert,
                    actionTitle: "Retry"
                )
            case .deletePerson:
                return UserFacingMessage(
                    title: "Couldn't delete",
                    message: "Please try again.",
                    style: .alert,
                    actionTitle: "Retry"
                )

            case .loadHistory:
                if isOffline(underlying) {
                    return offlineMessage(style: .toast)
                }
                return UserFacingMessage(
                    title: "Couldn't load history",
                    message: "Check your connection, then retry.",
                    style: .toast,
                    actionTitle: "Retry"
                )
            case .loadTrends:
                if isOffline(underlying) {
                    return offlineMessage(style: .toast)
                }
                return UserFacingMessage(
                    title: "Couldn't load trends",
                    message: "Check your connection, then retry.",
                    style: .toast,
                    actionTitle: "Retry"
                )
            case .loadAnalytics:
                if isOffline(underlying) {
                    return offlineMessage(style: .toast)
                }
                return UserFacingMessage(
                    title: "Couldn't load analytics",
                    message: "Check your connection, then retry.",
                    style: .toast,
                    actionTitle: "Retry"
                )

            case .exportCSV, .exportPDF:
                if let exportError = underlying as? ExportService.ExportError {
                    switch exportError {
                    case .noRecords:
                        return UserFacingMessage(
                            title: "Nothing to export",
                            message: "No records found.",
                            style: .alert
                        )
                    case .tooLarge:
                        return UserFacingMessage(
                            title: "Export too large",
                            message: "Try a smaller date range and export again.",
                            style: .alert,
                            actionTitle: "Retry"
                        )
                    case .writeFailed, .chunkingFailed:
                        return UserFacingMessage(
                            title: "Export failed",
                            message: "Could not generate the export file.",
                            style: .alert,
                            actionTitle: "Retry"
                        )
                    }
                }
                return UserFacingMessage(
                    title: "Export failed",
                    message: "Could not generate the export file.",
                    style: .alert,
                    actionTitle: "Retry"
                )
            }

        case .unknown(let error):
            if isOffline(error) {
                return offlineMessage(style: .alert)
            }
            return UserFacingMessage(
                title: "Something went wrong",
                message: "Please try again.",
                style: .alert,
                actionTitle: "Retry"
            )
        }
    }
}

private extension AppError {
    func isOffline(_ error: Error?) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }

    func offlineMessage(style: PresentationStyle, actionTitle: String? = "Retry") -> UserFacingMessage {
        UserFacingMessage(
            title: "You're offline",
            message: "Reconnect to the internet, then tap Retry. Your data stays saved on this iPad.",
            style: style,
            actionTitle: actionTitle
        )
    }
}
