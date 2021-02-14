import SwiftUI

// Credit goes to https://stackoverflow.com/a/62652866/1843020

// swiftlint:disable:next identifier_name
@ViewBuilder func FlipGroup<V1: View, V2: View>(
    flippedIf condition: Bool,
    @ViewBuilder _ content: @escaping () -> TupleView<(V1, V2)>
) -> some View {
    let pair = content()
    if condition {
        TupleView((pair.value.1, pair.value.0))
    } else {
        TupleView((pair.value.0, pair.value.1))
    }
}

struct FlipGroup_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                FlipGroup(flippedIf: false) {
                    Text("A")
                    Text("B")
                }
            }

            HStack {
                FlipGroup(flippedIf: true) {
                    Text("A")
                    Text("B")
                }
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
