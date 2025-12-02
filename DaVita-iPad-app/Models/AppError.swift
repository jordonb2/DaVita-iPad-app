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
                style: .alert
            )

        case .operation(let op, let underlying):
            switch op {
            case .loadPeople:
                return UserFacingMessage(title: "Couldn't load people", message: "Please try again.", style: .alert)
            case .savePerson:
                return UserFacingMessage(title: "Couldn't save", message: "Please try again.", style: .alert)
            case .deletePerson:
                return UserFacingMessage(title: "Couldn't delete", message: "Please try again.", style: .alert)

            case .loadHistory:
                return UserFacingMessage(title: "Couldn't load history", message: "Please try again.", style: .toast)
            case .loadTrends:
                return UserFacingMessage(title: "Couldn't load trends", message: "Please try again.", style: .toast)
            case .loadAnalytics:
                return UserFacingMessage(title: "Couldn't load analytics", message: "Please try again.", style: .toast)

            case .exportCSV, .exportPDF:
                if let exportError = underlying as? ExportService.ExportError {
                    switch exportError {
                    case .noRecords:
                        return UserFacingMessage(title: "Nothing to export", message: "No records found.", style: .alert)
                    case .writeFailed:
                        return UserFacingMessage(title: "Export failed", message: "Could not generate the export file.", style: .alert)
                    }
                }
                return UserFacingMessage(title: "Export failed", message: "Could not generate the export file.", style: .alert)
            }

        case .unknown:
            return UserFacingMessage(title: "Something went wrong", message: "Please try again.", style: .alert)
        }
    }
}


