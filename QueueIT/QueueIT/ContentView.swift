//
//  ContentView.swift
//  QueueIT
//
//  Created by Darragh Flynn on 12/10/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var vm = TrackSearchViewModel()

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text("QueueIT")
                    .bold(true)
                    .font(.headline)
                HStack {
                    TextField("Search tracks", text: $vm.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            Task { await vm.search() }
                        }
                    if vm.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.bottom, 4)

                if let message = vm.errorMessage, !message.isEmpty {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .padding()
            List {
                if vm.results.isEmpty {
                    Section("Results") {
                        Text("No results yet. Try searching above.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Results") {
                        ForEach(vm.results) { track in
                            NavigationLink {
                                VStack(spacing: 16) {
                                    if let url = track.imageUrl {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                            case .failure:
                                                Image(systemName: "music.note")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundStyle(.secondary)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(maxHeight: 240)
                                    }
                                    Text(track.name)
                                        .font(.title2)
                                        .bold()
                                    Text(track.artists)
                                        .foregroundStyle(.secondary)
                                    Text(track.album)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            } label: {
                                HStack(spacing: 12) {
                                    if let url = track.imageUrl {
                                        AsyncImage(url: url) { image in
                                            image.resizable()
                                        } placeholder: {
                                            Color.gray.opacity(0.2)
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        Image(systemName: "music.note")
                                            .frame(width: 48, height: 48)
                                            .background(Color.gray.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    VStack(alignment: .leading) {
                                        Text(track.name)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text(track.artists)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { Task { await vm.search() } }) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
            }
            .navigationBarTitle("QueueIT")
        }
        detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
