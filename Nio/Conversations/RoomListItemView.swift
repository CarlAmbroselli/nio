import SwiftUI
import SwiftMatrixSDK
import SDWebImageSwiftUI

struct RoomListItemContainerView: View {
    var room: NIORoom

    var body: some View {
        let lastMessage = room.lastMessage
        let lastActivity = Formatter.string(forRelativeDate: room.summary.lastMessageDate)

        var accessibilityLabel = ""
        if room.isDirect {
            accessibilityLabel = "DM with \(room.summary.displayname ?? ""), \(lastActivity) \(room.lastMessage)"
        } else {
            accessibilityLabel = "Room \(room.summary.displayname ?? ""), \(lastActivity) \(room.lastMessage)"
        }

        return RoomListItemView(title: room.summary.displayname ?? "",
                                subtitle: lastMessage,
                                rightDetail: lastActivity,
                                badge: room.summary.localUnreadEventCount,
                                roomAvatar: MXURL(mxContentURI: room.summary.avatar))
        .accessibility(label: Text(accessibilityLabel))
    }
}

struct RoomListItemView: View {
    var title: String
    var subtitle: String
    var rightDetail: String
    var badge: UInt
    var roomAvatar: MXURL?

    var gradient: LinearGradient {
        let tintColor: Color = .accentColor
        let colors = [
            tintColor.opacity(0.75),
            tintColor
        ]
        return LinearGradient(gradient: Gradient(colors: colors),
                       startPoint: .top,
                       endPoint: .bottom)
    }

    var prefixAvatar: some View {
        ZStack {
            Circle()
                .fill(gradient)
            Text(title.prefix(2).uppercased())
                .multilineTextAlignment(.center)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 40, height: 40)
        .accessibility(addTraits: .isImage)
    }

    var image: some View {
        if let avatarURL = roomAvatar?.contentURL {
            return AnyView(
                WebImage(url: avatarURL)
                    .resizable()
                    .placeholder { prefixAvatar }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .mask(Circle())
            )
        } else {
            return AnyView(
                prefixAvatar
            )
        }
    }

    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        HStack(alignment: .center) {
            image

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .padding(.bottom, 5)
                        .allowsTightening(true)
                    Spacer()
                    Text(rightDetail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .allowsTightening(true)
                    if badge != 0 {
                        Spacer()
                        ZStack {
                            Circle()
                                .foregroundColor(.accentColor)
                                .frame(width: 20, height: 20)
                            Text(String(badge))
                                .font(.caption)
                                .foregroundColor(.white)
                                .accessibility(label: Text("\(badge) new messages"))
                        }
                    }
                }
            }
        }
        .frame(height: 60 * sizeCategory.scalingFactor)
    }
}

//swiftlint:disable line_length
struct RoomListItemView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            RoomListItemView(title: "Morpheus",
                             subtitle: "Red or blue 💊?",
                             rightDetail: "10 minutes ago",
                             badge: 2,
                             roomAvatar: .demo)
            RoomListItemView(title: "Morpheus",
                             subtitle: "Red or blue 💊?",
                             rightDetail: "10 minutes ago",
                             badge: 0,
                             roomAvatar: .demo)
            RoomListItemView(title: "Morpheus",
                             subtitle: "Nesciunt quaerat voluptatem enim sunt. Provident id consequatur tempora nostrum. Sit in voluptatem consequuntur at et provident est facilis. Ut sit ad sit quam commodi qui.",
                             rightDetail: "12:29",
                             badge: 0,
                             roomAvatar: .demo)
            RoomListItemView(title: "A very long conversation title that breaks into the second line",
                             subtitle: "Nesciunt quaerat voluptatem enim sunt. Provident id consequatur tempora nostrum. Sit in voluptatem consequuntur at et provident est facilis. Ut sit ad sit quam commodi qui.",
                             rightDetail: "12:29",
                             badge: 1,
                             roomAvatar: .demo)
        }
//        .environment(\.sizeCategory, .extraExtraExtraLarge)
//        .environment(\.colorScheme, .dark)
        .accentColor(.purple)
    }
}
