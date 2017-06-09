//
//  CloudKitNotesManager.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/23/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitNotesManager : NotesManager {
    static var sharedInstance: NotesManager = CloudKitNotesManager(database: CKContainer.default().privateCloudDatabase)
    
    private let database: CKDatabase
    private let zoneID: CKRecordZoneID
    
    init(database: CKDatabase) {
        self.database = database
        self.zoneID = CKRecordZone.default().zoneID
    }
    
    func createDefaultFolder(completion: @escaping OperationCompletionBlock<Folder>) {
        let folder = CloudKitFolder.defaultFolder(inZone: zoneID)
        
        database.save(folder.record) { (record, error) in
            if let e = error as? CKError {
                if e.code == CKError.Code.serverRecordChanged {
                    // silently fail, it already exists...
                    let serverFolder = CloudKitFolder(record: e.serverRecord!)
                    completion(.success(serverFolder))
                } else {
                    completion(.error(e))
                }
            } else if let e = error {
                completion(.error(e))
            } else if let record = record {
                let folder = CloudKitFolder(record: record)
                completion(.success(folder))
            }
        }
    }
    
    func fetchFolders(completion: @escaping (Result<[Folder]>) -> Void) {
        let all = NSPredicate(value: true)
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        query(predicate: all,
              sortDescriptors: sortDescriptors,
              conversion: { (folder: CloudKitFolder) -> Folder in folder },
              completion: completion)
    }
    
    private func query<R, T>(predicate: NSPredicate, sortDescriptors: [NSSortDescriptor], conversion: @escaping (R) -> T, completion: @escaping OperationCompletionBlock<[T]>) where R : CKRecordWrapper {
        let query = CKQuery(recordType: R.RecordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        
        let queryOperation = CKQueryOperation(query: query)
        var results: [R] = []
        queryOperation.recordFetchedBlock = { record in
            results.append(R(record: record))
        }
        queryOperation.queryCompletionBlock = { cursor, error in
            // ignore cursor for now
            
            if let e = error as? CKError, e.code == CKError.Code.unknownItem {
                // we'll let the first save define it, for now just return an empty collection
                completion(.success([]))
            } else if let e = error {
                completion(.error(e))
            } else {
                completion(.success(results.map(conversion)))
            }
        }
        
        database.add(queryOperation)
    }
}
