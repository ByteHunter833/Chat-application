import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging, MulticastMessage } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();

type UserDocument = {
  name?: string;
  notificationTokens?: string[];
};

type ChatMessage = {
  content?: string;
  fileName?: string;
  senderId?: string;
  type?: string;
};

type CallInvitation = {
  callerId?: string;
  callerName?: string;
  calleeId?: string;
  chatId?: string;
  callId?: string;
  isVideoCall?: boolean;
};

export const onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data() as ChatMessage | undefined;
    const chatId = event.params.chatId;
    if (!message || !message.senderId || !chatId) {
      return;
    }

    if (message.type === "system") {
      return;
    }

    const chatSnapshot = await firestore.doc(`chats/${chatId}`).get();
    const chatData = chatSnapshot.data();
    const members = Array.isArray(chatData?.members)
      ? (chatData?.members as string[])
      : [];
    const recipientIds = members.filter((memberId) => memberId !== message.senderId);
    if (!recipientIds.length) {
      return;
    }

    const senderSnapshot = await firestore.doc(`users/${message.senderId}`).get();
    const sender = senderSnapshot.data() as UserDocument | undefined;
    const senderName = sender?.name?.trim() || "New message";
    const body = buildMessageBody(message);

    await Promise.all(
      recipientIds.map((userId) =>
        sendPushToUser(userId, {
          notification: {
            title: senderName,
            body,
          },
          data: {
            type: "chat_message",
            chatId,
            senderId: message.senderId ?? "",
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        }),
      ),
    );
  },
);

export const onCallInvitationCreated = onDocumentCreated(
  "callInvitations/{callId}",
  async (event) => {
    const invitation = event.data?.data() as CallInvitation | undefined;
    if (
      !invitation ||
      !invitation.calleeId ||
      !invitation.callId ||
      !invitation.chatId
    ) {
      return;
    }

    const isVideoCall = invitation.isVideoCall === true;
    const callerName = invitation.callerName?.trim() || "Someone";

    await sendPushToUser(invitation.calleeId, {
      notification: {
        title: isVideoCall ? "Incoming video call" : "Incoming call",
        body: `${callerName} is calling you`,
      },
      data: {
        type: "call_invitation",
        callId: invitation.callId,
        chatId: invitation.chatId,
        callerId: invitation.callerId ?? "",
        callerName,
        isVideoCall: String(isVideoCall),
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
            "content-available": 1,
          },
        },
      },
    });
  },
);

function buildMessageBody(message: ChatMessage): string {
  switch (message.type) {
    case "image":
      return "Photo";
    case "video":
      return "Video";
    case "file":
      return message.fileName?.trim() || "File";
    case "voice":
      return "Voice message";
    default:
      return message.content?.trim() || "New message";
  }
}

async function sendPushToUser(
  userId: string,
  message: Omit<MulticastMessage, "tokens">,
): Promise<void> {
  const userSnapshot = await firestore.doc(`users/${userId}`).get();
  const user = userSnapshot.data() as UserDocument | undefined;
  const tokens = Array.isArray(user?.notificationTokens)
    ? user?.notificationTokens.filter((token): token is string => token.length > 0)
    : [];

  if (!tokens.length) {
    logger.debug(`No FCM tokens registered for user ${userId}`);
    return;
  }

  const response = await messaging.sendEachForMulticast({
    ...message,
    tokens,
  });

  const invalidTokens = response.responses
    .map((result, index) => ({ result, token: tokens[index] }))
    .filter(({ result }) =>
      result.error?.code === "messaging/registration-token-not-registered" ||
      result.error?.code === "messaging/invalid-registration-token",
    )
    .map(({ token }) => token);

  if (!invalidTokens.length) {
    return;
  }

  logger.warn(`Removing ${invalidTokens.length} invalid tokens for user ${userId}`);
  await firestore.doc(`users/${userId}`).set(
    {
      notificationTokens: tokens.filter((token) => !invalidTokens.includes(token)),
    },
    { merge: true },
  );
}
