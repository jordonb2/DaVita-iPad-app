//
//  PeopleListViewModel.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/4/25.
//

import Foundation
import CoreData

final class PeopleListViewModel: NSObject {
    /// Push-driven change notification for the owning view/controller.
    var onPeopleChanged: (([Person]) -> Void)?

    private(set) var people: [Person] = []

    // User-visible error hooks (set by the owning VC).
    var onUserToast: ((String) -> Void)?
    var onUserAlert: ((String, String?) -> Void)?
    var onError: ((AppError) -> Void)?

    private let personService: PersonServicing
    private let peopleRepo: PersonRepositorying

    private lazy var frc: NSFetchedResultsController<Person> = {
        return peopleRepo.makePeopleFRC(delegate: self)
    }()

    init(peopleRepo: PersonRepositorying,
         personService: PersonServicing) {
        self.peopleRepo = peopleRepo
        self.personService = personService
        super.init()
        do {
            try frc.performFetch()
            people = frc.fetchedObjects ?? []
            onPeopleChanged?(people)
        } catch {
            AppLog.persistence.error("FRC performFetch error: \(error, privacy: .public)")
            emit(AppError(operation: .loadPeople, underlying: error))
        }

    }

    private func emit(_ error: AppError) {
        onError?(error)

        // Backward-compatible fallbacks if callers still use the older hooks.
        let ui = error.userFacing
        switch ui.style {
        case .toast:
            onUserToast?(ui.message ?? ui.title)
        case .alert:
            onUserAlert?(ui.title, ui.message)
        }
    }

    // MARK: - CRUD

    func add(name: String, gender: Gender? = nil, dob: Date? = nil, checkInData: PersonCheckInData? = nil) {
        guard let sanitizedName = InputSanitizer.personName(name) else {
            AppLog.ui.warning("Refusing to add Person with empty name")
            emit(.validation(.emptyName))
            return
        }

        do {
            try personService.addPerson(name: sanitizedName, gender: gender, dob: dob, checkInData: checkInData)
#if DEBUG
            AppLog.ui.debug("[ADD] Person saved → Name: \(sanitizedName, privacy: .private)")
#endif
        } catch {
            AppLog.persistence.error("Add person error: \(error, privacy: .public)")
            emit(AppError(error, defaultOperation: .savePerson))
        }
    }

    func delete(_ person: Person) {
        do {
            try personService.deletePerson(personID: person.objectID)
        } catch {
            AppLog.persistence.error("Delete person error: \(error, privacy: .public)")
            emit(AppError(error, defaultOperation: .deletePerson))
        }
    }
    
    func update(_ person: Person, name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData? = nil) {
        guard let sanitizedName = InputSanitizer.personName(name) else {
            AppLog.ui.warning("Refusing to update Person with empty name")
            emit(.validation(.emptyName))
            return
        }

        do {
            try personService.updatePerson(personID: person.objectID, name: sanitizedName, gender: gender, dob: dob, checkInData: checkInData)
#if DEBUG
            AppLog.ui.debug("[UPDATE] Person saved → Name: \(sanitizedName, privacy: .private)")
#endif
        } catch {
            AppLog.persistence.error("Update person error: \(error, privacy: .public)")
            emit(AppError(error, defaultOperation: .savePerson))
        }
    }

    // Convenience
    func person(at indexPath: IndexPath) -> Person {
        return people[indexPath.row]
    }

    var count: Int { people.count }
}

// MARK: - NSFetchedResultsControllerDelegate
extension PeopleListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        people = frc.fetchedObjects ?? []
        onPeopleChanged?(people)
    }
}

