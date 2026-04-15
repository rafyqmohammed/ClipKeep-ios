//
//  ClipListViewModel.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
class ClipListViewModel: ObservableObject {
    @Published var clips: [ClipItem] = []
    
    func deleteClip(_ item: ClipItem, context: ModelContext) {
        context.delete(item)
        try? context.save()
    }
    
    func clearAll(context: ModelContext) {
        do {
            try context.delete(model: ClipItem.self)
            try context.save()
        } catch {
            print("Erreur lors de la suppression: \(error)")
        }
    }
}
