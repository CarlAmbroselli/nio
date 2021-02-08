import SwiftUI
import Combine
import MatrixSDK

import NioKit

struct RoomContainerView: View {
    @ObservedObject var room: NIORoom

    @State var showAttachmentPicker = false
    @State var showImagePicker = false
    @State var eventToReactTo: String?
    @State var showJoinAlert = false

    var body: some View {
        RoomView(
            events: room.events(),
            isDirect: room.isDirect,
            showAttachmentPicker: $showAttachmentPicker,
            onCommit: { message in
                self.room.send(text: message)
            },
            onReact: { eventId in
                self.eventToReactTo = eventId
            },
            onRedact: { eventId, reason in
                self.room.redact(eventId: eventId, reason: reason)
            },
            onEdit: { message, eventId in
                self.room.edit(text: message, eventId: eventId)
            }
        )
        .navigationBarTitle(Text(room.summary.displayname ?? ""), displayMode: .inline)
        .actionSheet(isPresented: $showAttachmentPicker) {
            self.attachmentPickerSheet
        }
        .sheet(item: $eventToReactTo) { eventId in
            ReactionPicker { reaction in
                self.room.react(toEventId: eventId, emoji: reaction)
                self.eventToReactTo = nil
            }
        }
        .alert(isPresented: $showJoinAlert) {
            let roomName = self.room.summary.displayname ?? self.room.summary.roomId ?? L10n.Room.Invitation.fallbackTitle
            return Alert(
                title: Text(L10n.Room.Invitation.JoinAlert.title),
                message: Text(L10n.Room.Invitation.JoinAlert.message(roomName)),
                primaryButton: .default(
                    Text(L10n.Room.Invitation.JoinAlert.joinButton),
                    action: {
                        self.room.room.mxSession.joinRoom(self.room.room.roomId) { _ in
                            self.room.markAllAsRead()
                        }
                    }),
                secondaryButton: .cancel())
        }
        .onAppear {
            switch self.room.summary.membership {
            case .invite:
                self.showJoinAlert = true
            case .join:
                self.room.markAllAsRead()
            default:
                break
            }
        }
        .environmentObject(room)
        .background(EmptyView()
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    self.room.sendImage(image: image)
                }
            }
        )
    }

    var attachmentPickerSheet: ActionSheet {
        ActionSheet(
            title: Text(L10n.Room.Attachment.selectType), buttons: [
                .default(Text(L10n.Room.Attachment.typePhoto), action: {
                    self.showImagePicker = true
                }),
                .cancel()
            ]
        )
    }
}

struct RoomView: View {
    @Environment(\.userId) var userId
    @EnvironmentObject var room: NIORoom

    var events: EventCollection
    var isDirect: Bool

    @Binding var showAttachmentPicker: Bool
    var onCommit: (String) -> Void

    var onReact: (String) -> Void
    var onRedact: (String, String?) -> Void
    var onEdit: (String, String) -> Void

    @State private var editEventId: String?
    @State private var eventToRedact: String?

    @State private var highlightMessage: String?
    @State private var isEditingMessage: Bool = false
    @State private var attributedMessage = NSAttributedString(string: "")

    typealias TopOfScrollKey = BoolKey
    typealias BottomOfScrollKey = BoolKey
    @State private var shouldAutoScroll = false
    @State private var shouldPaginate = false

    var body: some View {
        VStack {
            GeometryReader { outerGeometry in
                ScrollView {
                    ScrollViewReader { reader in
                        ZStack {
                            GeometryReader { innerGeometry in
                                let topIsVisible = innerGeometry.frame(in: .global).minY >= outerGeometry.frame(in: .global).minY
                                let bottomIsVisible = innerGeometry.frame(in: .global).maxY <= outerGeometry.frame(in: .global).maxY
                                RoundedRectangle(cornerRadius: 100)
                                    .foregroundColor(bottomIsVisible ? .green : topIsVisible ? .red : .yellow)
                                    .preference(key: TopOfScrollKey.self, value: topIsVisible)
                                    .preference(key: BottomOfScrollKey.self, value: bottomIsVisible)
                            }
                            .onPreferenceChange(TopOfScrollKey.self) {
                                shouldPaginate = $0
                            }
                            .onPreferenceChange(BottomOfScrollKey.self) {
                                shouldAutoScroll = $0
                            }
                            VStack {
                                ForEach(events.renderableEvents) { event in
                                    EventContainerView(event: event,
                                                       reactions: self.events.reactions(for: event),
                                                       connectedEdges: self.events.connectedEdges(of: event),
                                                       showSender: !self.isDirect,
                                                       edits: self.events.relatedEvents(of: event).filter { $0.isEdit() },
                                                       contextMenuModel: EventContextMenuModel(
                                                        event: event,
                                                        userId: self.userId,
                                                        onReact: { self.onReact(event.eventId) },
                                                        onReply: { },
                                                        onEdit: { self.edit(event: event) },
                                                        onRedact: {
                                                            if event.sentState == MXEventSentStateFailed {
                                                                room.removeOutgoingMessage(event)
                                                            } else {
                                                                self.eventToRedact = event.eventId
                                                            }
                                                        }))
                                        .padding(.horizontal)
                                        .id(event.eventId)
                                }
                            }
                        }
                        .onAppear {
                            reader.scrollTo(events.renderableEvents.last?.eventId, anchor: .bottom)
                        }
                        .onReceive(room.objectWillChange) {
                            if shouldAutoScroll {
                                reader.scrollTo(events.renderableEvents.last?.eventId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            if !(room.room.typingUsers?.filter { $0 != userId }.isEmpty ?? false) {
                TypingIndicatorContainerView()
            }
            MessageComposerView(
                showAttachmentPicker: $showAttachmentPicker,
                isEditing: $isEditingMessage,
                attributedMessage: $attributedMessage,
                highlightMessage: highlightMessage,
                onCancel: cancelEdit,
                onCommit: send
            )
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .alert(item: $eventToRedact) { eventId in
            Alert(title: Text(L10n.Room.Remove.title),
                  message: Text(L10n.Room.Remove.message),
                  primaryButton: .destructive(Text(L10n.Room.Remove.action), action: { self.onRedact(eventId, nil) }),
                  secondaryButton: .cancel())
        }
    }

    private func send() {
        if editEventId == nil {
            onCommit(attributedMessage.string)
            attributedMessage = NSAttributedString(string: "")
        } else {
            onEdit(attributedMessage.string, editEventId!)
            attributedMessage = NSAttributedString(string: "")
            editEventId = nil
            highlightMessage = nil
        }
    }

    private func edit(event: MXEvent) {
        attributedMessage = NSAttributedString(string: event.content["body"] as? String ?? "")
        highlightMessage = attributedMessage.string
        editEventId = event.eventId
    }

    private func cancelEdit() {
        editEventId = nil
        highlightMessage = nil
        attributedMessage = NSAttributedString(string: "")
    }
}
