//
//  ContentView.swift
//  Applite
//
//  Created by Milán Várady on 2022. 09. 24..
//

import SwiftUI
import OSLog
import ButtonKit
import DebouncedOnChange

struct ContentView: View {
    @EnvironmentObject var caskManager: CaskManager
    
    /// Currently selected tab in the sidebar
    @State var selection: SidebarItem = .home

    @StateObject var loadAlert = AlertManager()

    @State var brokenInstall = false
    
    /// If true the sidebar is disabled
    @State var modifyingBrew = false

    /// App search query
    @State var searchInput = ""
    @State var showSearchResults = false

    // Sorting options
    @AppStorage(Preferences.searchSortOption.rawValue) var sortBy = SortingOptions.mostDownloaded
    @AppStorage(Preferences.hideUnpopularApps.rawValue) var hideUnpopularApps = false
    @AppStorage(Preferences.hideDisabledApps.rawValue) var hideDisabledApps = false

    let logger = Logger()

    var body: some View {
        NavigationSplitView {
            sidebarViews
                .disabled(modifyingBrew)
        } detail: {
            detailView
        }
        // Load all cask releated data
        .task {
            await loadCasks()
        }
        // MARK: - Search
        .searchable(text: $searchInput, placement: .sidebar)
        // Live search with debounce
        .task(id: searchInput, debounceTime: .milliseconds(300)) {
            if searchInput.isEmpty {
                showSearchResults = false
            } else {
                await performSearch()
            }
        }
        // Submit search (immediate, bypasses debounce)
        .onSubmit(of: .search) {
            Task {
                if !searchInput.isEmpty {
                    await performSearch()
                }
            }
        }
        // Limit search characters
        .onChange(of: searchInput) { newValue in
            if newValue.count > 30 {
                searchInput = String(newValue.prefix(30))
            }
        }
        // Apply sorting options
        .task(id: sortBy) {
            // Refilter if sorting options change
            await sortCasks(ignoreBestMatch: false)
        }
        // Apply filter option
        .task(id: hideUnpopularApps) {
            if hideUnpopularApps {
                await filterUnpopular()
            } else {
                await caskManager.allCasks.search(query: searchInput)
            }
        }
        .task(id: hideDisabledApps) {
            if hideDisabledApps {
                await filterDisabled()
            } else {
                await caskManager.allCasks.search(query: searchInput)
            }
        }
        // Load failure alert
        .alert(loadAlert.title, isPresented: $loadAlert.isPresented) {
            AsyncButton {
                await loadCasks()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }

            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }

            Button("OK", role: .cancel) { }
        } message: {
            Text(loadAlert.message)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
