import SwiftUI
import SwiftData

/// Sidebar view displaying the list of applications.
/// Supports selection, context menu for delete/rename, and adding new apps.
/// Requirements: 1.3, 1.4, 1.5
struct SidebarView: View {
    @Bindable var viewModel: AppViewModel
    
    @State private var showingAddAppSheet = false
    @State private var newAppName = ""
    @State private var appToEdit: AppItem?
    @State private var showingDeleteConfirmation = false
    @State private var appToDelete: AppItem?
    
    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedApp },
            set: { viewModel.selectApp($0) }
        )) {
            ForEach(viewModel.apps, id: \.id) { app in
                AppRowView(app: app)
                    .tag(app)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .contextMenu {
                        Button("Edit...") {
                            appToEdit = app
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            appToDelete = app
                            showingDeleteConfirmation = true
                        }
                    }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.apps.map { $0.id })
        }
    
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddAppSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Add Application")
            }
        }
        .sheet(isPresented: $showingAddAppSheet) {
            AddAppSheet(
                appName: $newAppName,
                onAdd: { iconPath in
                    viewModel.addApp(name: newAppName, iconPath: iconPath)
                    newAppName = ""
                    showingAddAppSheet = false
                },
                onCancel: {
                    newAppName = ""
                    showingAddAppSheet = false
                }
            )
        }

        .sheet(item: $appToEdit) { app in
            EditAppSheet(
                app: app,
                onSave: { newName, newIconPath in
                    viewModel.updateApp(app, name: newName, iconPath: newIconPath)
                    appToEdit = nil
                },
                onCancel: {
                    appToEdit = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Application",
            isPresented: $showingDeleteConfirmation,
            presenting: appToDelete
        ) { app in
            Button("Delete", role: .destructive) {
                viewModel.deleteApp(app)
                appToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                appToDelete = nil
            }
        } message: { app in
            Text("Are you sure you want to delete \"\(app.name)\"? This will also delete all associated shortcuts.")
        }
        
    }
}

// MARK: - Add App Sheet

private struct AddAppSheet: View {
    @Binding var appName: String
    let onAdd: (String?) -> Void  // Now passes iconPath
    let onCancel: () -> Void
    
    @State private var selectedIconPath: String?
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Application")
                .font(.headline)
            
            // Icon picker
            AppIconPicker(selectedIconPath: $selectedIconPath, appName: $appName)
            
            TextField("Application Name", text: $appName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit {
                    if !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAdd(selectedIconPath)
                    }
                }
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    onAdd(selectedIconPath)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            isNameFieldFocused = true
        }
    }
}

// MARK: - Edit App Sheet

private struct EditAppSheet: View {
    let app: AppItem
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void
    
    @State private var appName: String = ""
    @State private var selectedIconPath: String?
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Application")
                .font(.headline)
            
            // Icon picker
            AppIconPicker(selectedIconPath: $selectedIconPath, appName: $appName)
            
            TextField("Application Name", text: $appName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit {
                    if !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave(appName, selectedIconPath)
                    }
                }
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    onSave(appName, selectedIconPath)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            appName = app.name
            selectedIconPath = app.iconPath
            isNameFieldFocused = true
        }
    }
}

#Preview {
    SidebarView(viewModel: AppViewModel(dataService: DataService(modelContext: try! ModelContainer(for: AppItem.self, ShortcutItem.self).mainContext)))
        .modelContainer(for: [AppItem.self, ShortcutItem.self], inMemory: true)
}
