//
//  ClipKeepApp.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData
import Combine
import BackgroundTasks

@main
struct ClipKeepApp: App {
    let modelContainer: ModelContainer
    @State private var clipboardStore = ClipboardStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            modelContainer = try ModelContainer(for: ClipItem.self)
        } catch {
            let storeURL = ModelConfiguration().url
            try? FileManager.default.removeItem(at: storeURL)
            do {
                modelContainer = try ModelContainer(for: ClipItem.self)
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }

        // Enregistre le BGAppRefreshTask au lancement de l'app.
        // iOS appellera ce handler périodiquement (toutes les ~15 min minimum)
        // pour traiter les clips capturés par le clavier même si l'app n'est pas ouverte.
        let container = modelContainer
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.rafyq.ClipKeep.clipboardRefresh",
            using: nil
        ) { task in
            ClipKeepApp.handleBackgroundRefresh(
                task: task as! BGAppRefreshTask,
                container: container
            )
        }
    }

    @StateObject private var langManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(clipboardStore)
                .environmentObject(langManager)
                .environment(\.layoutDirection, langManager.isRTL ? .rightToLeft : .leftToRight)
                .id(langManager.current)
                .task {
                    clipboardStore.initialSync(context: modelContainer.mainContext)
                }
                .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
                    Task {
                        clipboardStore.checkClipboard(context: modelContainer.mainContext)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Chaque fois que l'utilisateur revient dans ClipKeep, on applique
                // immédiatement les épingles et clips capturés en attente.
                clipboardStore.initialSync(context: modelContainer.mainContext)
            } else if newPhase == .background {
                // Planifie le prochain réveil en arrière-plan dès que l'app passe en fond.
                ClipKeepApp.scheduleBackgroundRefresh()
            }
        }
    }

    // Planifie le prochain BGAppRefreshTask.
    // iOS respecte une fenêtre minimale de ~15 minutes entre les réveils,
    // mais peut attendre plus longtemps selon l'activité de l'appareil.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.rafyq.ClipKeep.clipboardRefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // Handler appelé par iOS quand le BGAppRefreshTask se déclenche.
    // Deux tentatives de capture :
    //   1. Lecture directe du presse-papiers (fonctionne si iOS l'autorise selon la version)
    //   2. Traitement des clips capturés par le clavier (captured_clips.json)
    static func handleBackgroundRefresh(task: BGAppRefreshTask, container: ModelContainer) {
        // Planifie immédiatement le suivant pour maintenir la chaîne de réveils.
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            let context = container.mainContext
            let store = ClipboardStore()

            // Tentative 1 : lecture directe du presse-papiers.
            // iOS peut autoriser cet accès pendant un BGTask (app en cours d'exécution).
            // Si UIPasteboard retourne nil (bloqué par iOS), ce bloc est ignoré silencieusement.
            if let text = UIPasteboard.general.string,
               !text.isEmpty,
               let data = text.data(using: .utf8) {
                let descriptor = FetchDescriptor<ClipItem>()
                let all = (try? context.fetch(descriptor)) ?? []
                if !all.contains(where: { $0.contentData == data }) {
                    let type: ClipType = text.hasPrefix("http") ? .url : .text
                    context.insert(ClipItem(contentData: data, type: type))
                    try? context.save()
                }
            }

            // Tentative 2 : clips capturés par le clavier pendant la session de frappe.
            store.processCapturedClips(context: context)
            store.syncAll(context: context)

            task.setTaskCompleted(success: true)
        }
    }
}
