import SwiftUI

struct IncrementPickerView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Binding var isPresented: Bool

    private let options = [1, 2, 5, 10, 25, 50, 100]

    var body: some View {
        VStack(spacing: 12) {
            Text("Score Increment")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { value in
                    Button {
                        viewModel.increment = value
                        HapticManager.light()
                        isPresented = false
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 18, weight: .bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(
                                viewModel.increment == value
                                    ? ColorPalette.color(from: "#2ECC40").opacity(0.2)
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                viewModel.increment == value
                                    ? ColorPalette.color(from: "#2ECC40")
                                    : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        viewModel.increment == value
                                            ? ColorPalette.color(from: "#2ECC40")
                                            : Color(.systemGray4),
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .presentationDetents([.height(120)])
        .presentationDragIndicator(.visible)
    }
}
