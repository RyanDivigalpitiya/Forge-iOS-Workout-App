import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: GlobalSettings

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        Button {
                            settings.colorTheme = theme
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 36, height: 36)
                                    if settings.colorTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                Text(theme.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(GlobalSettings.shared.bgColor)
            } header: {
                Text("Accent Color")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.black)
        .navigationTitle("Settings")
        .navigationBarTitleTextColor(settings.fgColor)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(GlobalSettings.shared)
                .preferredColorScheme(.dark)
        }
    }
}
