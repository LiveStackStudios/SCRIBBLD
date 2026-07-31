/**
 * SCRIBBLD push-notification Cloud Functions.
 *
 * Three Firestore triggers, all v2-style:
 *   1. onInviteCreated  — /users/{uid}/invites/{gameId} create →
 *      notify the recipient that a friend has challenged them.
 *   2. onGameJoined     — /games/{gameId} update where players list
 *      grew → notify the existing players that someone joined.
 *   3. onLobbyReady     — /games/{gameId} update where the lobby
 *      just reached `maxPlayers` → notify everyone that the game
 *      is ready to start.
 *
 * FCM tokens live on the user profile doc at `users/{uid}.fcmToken`
 * (single token; PushService.persistToken writes it merge:true on
 * every app launch + token rotation).
 *
 * Errors are caught and logged — a failed notification must NEVER
 * fail the Firestore write that triggered it.
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Pull a single FCM token for a uid, or null.
 *
 * Tokens live at `users/{uid}/private/push` — NOT on the profile doc, which
 * is readable by every signed-in user so friend search works. The legacy
 * `users/{uid}.fcmToken` field is still read as a fallback so any device that
 * registered before the move keeps receiving notifications.
 */
async function tokenForUID(uid) {
  try {
    const privSnap = await db
      .collection("users").doc(uid)
      .collection("private").doc("push")
      .get();
    const priv = privSnap.data() || {};
    if (typeof priv.fcmToken === "string" && priv.fcmToken.length > 0) {
      return priv.fcmToken;
    }
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.data() || {};
    const t = data.fcmToken;
    return typeof t === "string" && t.length > 0 ? t : null;
  } catch (err) {
    logger.warn("tokenForUID failed", { uid, err: String(err) });
    return null;
  }
}

/**
 * Names on invites and game docs are client-written, so they reach us as
 * arbitrary strings and get rendered into notification titles. Collapse
 * newlines and cap the length so a crafted display name can't fake extra
 * lines of notification copy.
 */
function safeName(raw, fallback) {
  if (typeof raw !== "string") return fallback;
  const cleaned = raw.replace(/\s+/g, " ").trim().slice(0, 32);
  return cleaned.length > 0 ? cleaned : fallback;
}

/** Pull FCM tokens for a list of uids — drops null/empty. */
async function tokensForUIDs(uids) {
  const all = await Promise.all((uids || []).map(tokenForUID));
  return all.filter(Boolean);
}

/** Pretty game-kind label for notification copy. */
function gameKindLabel(kind) {
  switch (kind) {
    case "ticTacToe":    return "Tic Tac Toe";
    case "dotsAndBoxes": return "Dots & Boxes";
    case "hangman":      return "Hangman";
    case "stop":         return "Stop!";
    default:             return "a game";
  }
}

/** Send to a list of tokens, swallow errors. */
async function safeSend(tokens, payload) {
  if (!tokens || tokens.length === 0) return;
  try {
    const message = {
      tokens,
      notification: payload.notification,
      data: payload.data || {},
      apns: {
        payload: {
          aps: {
            sound: "default",
            "content-available": 1
          }
        }
      }
    };
    const res = await messaging.sendEachForMulticast(message);
    logger.info("multicast result", {
      success: res.successCount,
      failure: res.failureCount,
      tokens: tokens.length
    });
    // Clean up dead tokens so we don't keep notifying tombstones.
    res.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code;
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token") {
          // Token belongs to an uninstall / reinstall — we don't know
          // which user this token is for in this multicast, so the
          // best we can do is log it. PushService re-registers on
          // every launch, so stale tokens are short-lived anyway.
          logger.info("dead token", { token: tokens[i].slice(0, 12) + "…" });
        }
      }
    });
  } catch (err) {
    logger.error("safeSend failed", { err: String(err) });
  }
}

// ============================================================
// 1. /users/{uid}/invites/{gameId} create → notify recipient
// ============================================================
exports.onInviteCreated = onDocumentCreated(
  {
    document: "users/{uid}/invites/{gameId}",
    region: "us-central1"
  },
  async (event) => {
    const uid = event.params.uid;
    const gameId = event.params.gameId;
    const invite = event.data && event.data.data();
    if (!invite) return;

    const token = await tokenForUID(uid);
    if (!token) {
      logger.info("invite created but no FCM token for recipient", { uid });
      return;
    }

    // Inviter name: prefer the invite's `fromName`, fallback to the
    // inviter's user-doc displayName.
    let inviterName = invite.fromName;
    if (!inviterName && invite.from) {
      try {
        const inviterSnap = await db.collection("users").doc(invite.from).get();
        inviterName = (inviterSnap.data() || {}).displayName;
      } catch (_) { /* swallow */ }
    }
    inviterName = safeName(inviterName, "A friend");

    const kindLabel = gameKindLabel(invite.type);

    await safeSend([token], {
      notification: {
        title: `${inviterName} challenged you to ${kindLabel}!`,
        body: "Tap to join the game."
      },
      data: {
        type: "invite",
        gameId,
        kind: String(invite.type || ""),
        click_action: "OPEN_INVITE"
      }
    });
  }
);

// ============================================================
// 2. /games/{gameId} update where players grew → notify existing
//    (and 3. on the same trigger — once lobby hits maxPlayers,
//    fire a "ready to play" to everyone).
// ============================================================
exports.onGameJoined = onDocumentUpdated(
  {
    document: "games/{gameId}",
    region: "us-central1"
  },
  async (event) => {
    const gameId = event.params.gameId;
    const before = (event.data && event.data.before.data()) || {};
    const after  = (event.data && event.data.after.data())  || {};

    const beforePlayers = before.players || [];
    const afterPlayers  = after.players  || [];

    // Only act if the player list grew. Other updates (moves, scores,
    // phase changes) shouldn't fire join notifications.
    if (afterPlayers.length <= beforePlayers.length) return;

    const newcomers = afterPlayers.filter((p) => !beforePlayers.includes(p));
    const existing  = beforePlayers; // were here before this update

    const playerNames = after.playerNames || {};
    const joinerName  = safeName(playerNames[newcomers[0]], "Someone");
    const kind        = after.type;
    const kindLabel   = gameKindLabel(kind);
    const maxPlayers  = after.maxPlayers || 2;
    const lobbyReady  = afterPlayers.length >= maxPlayers;

    // -- Trigger 2: notify the players who were already here. --
    if (existing.length > 0) {
      const tokens = await tokensForUIDs(existing);
      const title = lobbyReady
        ? `Ready to play ${kindLabel}!`
        : `${joinerName} joined the lobby`;
      const body  = lobbyReady
        ? "Everyone is in. Tap to start the game."
        : `Waiting on more players. Tap to view the lobby.`;
      await safeSend(tokens, {
        notification: { title, body },
        data: {
          type: lobbyReady ? "ready" : "joined",
          gameId,
          kind: String(kind || ""),
          click_action: lobbyReady ? "OPEN_GAME" : "OPEN_LOBBY"
        }
      });
    }

    // -- Trigger 3: also notify the NEWCOMER themselves if the lobby
    //    is now ready, so they get the same "Tap to start" prompt.
    //    Skip when not ready so they don't get an immediate ding on
    //    their own join (their UI already navigated there).
    if (lobbyReady && newcomers.length > 0) {
      const newcomerTokens = await tokensForUIDs(newcomers);
      await safeSend(newcomerTokens, {
        notification: {
          title: `Ready to play ${kindLabel}!`,
          body:  "The lobby is full. Tap to start."
        },
        data: {
          type: "ready",
          gameId,
          kind: String(kind || ""),
          click_action: "OPEN_GAME"
        }
      });
    }
  }
);

// ============================================================
// 4. deleteAccount — callable, App Store Guideline 5.1.1(v)
// ============================================================
//
// Any app offering account creation must let the user delete the account
// from inside the app. "Email us to delete" is explicitly not sufficient.
//
// This runs server-side because a client cannot clean up the records that
// live on OTHER users' documents — their copy of the friendship, a pending
// invite they were sent — and security rules rightly forbid it.
//
// Deliberately best-effort per step: a failure cleaning up one peer must not
// leave the account half-deleted. The Auth record is deleted LAST, so if
// anything throws the user still has an account and can retry.
exports.deleteAccount = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before deleting your account.");
  }
  logger.info("deleteAccount requested", { uid });

  const summary = { friendsRemoved: 0, invitesRemoved: 0, requestsRemoved: 0, gamesAnonymised: 0 };

  // 1. Remove our entry from every peer's friends list, and drop any friend
  //    request we sent them. Both live under a document we don't own.
  try {
    const myFriends = await db.collection("users").doc(uid).collection("friends").get();
    for (const doc of myFriends.docs) {
      const peer = doc.id;
      await db.collection("users").doc(peer).collection("friends").doc(uid).delete()
        .then(() => { summary.friendsRemoved += 1; })
        .catch((err) => logger.warn("peer friend delete failed", { peer, err: String(err) }));
      await db.collection("users").doc(peer).collection("friendRequests").doc(uid).delete()
        .catch(() => { /* usually absent */ });
    }
  } catch (err) {
    logger.warn("friend cleanup failed", { uid, err: String(err) });
  }

  // 2. Outgoing friend requests and invites sitting in other people's inboxes.
  //    Collection-group queries find them without knowing who we wrote to.
  for (const [group, field, counter] of [
    ["friendRequests", "fromUID", "requestsRemoved"],
    ["invites", "from", "invitesRemoved"],
  ]) {
    try {
      const snap = await db.collectionGroup(group).where(field, "==", uid).get();
      for (const doc of snap.docs) {
        await doc.ref.delete()
          .then(() => { summary[counter] += 1; })
          .catch((err) => logger.warn("outgoing delete failed", { path: doc.ref.path, err: String(err) }));
      }
    } catch (err) {
      logger.warn(`${group} sweep failed`, { uid, err: String(err) });
    }
  }

  // 3. Games. We do NOT delete these outright — the opponent didn't ask to
  //    lose their game. Strip the departing user's name (the only personal
  //    data in the document), mark the game abandoned so nobody is left
  //    waiting on a turn that will never come, and stamp expiresAt so the
  //    existing TTL policy sweeps it within a day.
  try {
    const games = await db.collection("games").where("players", "array-contains", uid).get();
    const expires = admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
    for (const doc of games.docs) {
      const names = doc.data().playerNames || {};
      if (names[uid] !== undefined) names[uid] = "Former player";
      await doc.ref.update({
        playerNames: names,
        status: "abandoned",
        expiresAt: expires,
        updatedAt: admin.firestore.Timestamp.now(),
      })
        .then(() => { summary.gamesAnonymised += 1; })
        .catch((err) => logger.warn("game anonymise failed", { game: doc.id, err: String(err) }));
    }
  } catch (err) {
    logger.warn("game sweep failed", { uid, err: String(err) });
  }

  // 4. Our own document tree: profile, friends, friendRequests, invites,
  //    blocked, and the private push-token doc.
  try {
    await db.recursiveDelete(db.collection("users").doc(uid));
  } catch (err) {
    logger.error("user doc delete failed", { uid, err: String(err) });
    throw new HttpsError("internal", "Could not delete your data. Nothing was removed — please try again.");
  }

  // 5. Auth record last: while it exists the user can retry.
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    logger.error("auth delete failed", { uid, err: String(err) });
    throw new HttpsError("internal", "Your data was removed but the sign-in record could not be deleted. Contact support.");
  }

  logger.info("deleteAccount complete", { uid, ...summary });
  return { ok: true, ...summary };
});

// ============================================================
// 5. onReportCreated — log so reports are visible in Cloud Logging
// ============================================================
//
// App Store Guideline 1.2 requires a way to report objectionable content AND
// a mechanism for acting on it. Reports are written client-side to /reports
// (create-only; no client can read them back). This surfaces each one in the
// logs so it's actually reviewable without opening the console.
exports.onReportCreated = onDocumentCreated(
  { document: "reports/{reportId}", region: "us-central1" },
  async (event) => {
    const r = (event.data && event.data.data()) || {};
    logger.warn("USER REPORT", {
      reportId: event.params.reportId,
      reporter: r.reporterUID,
      reported: r.reportedUID,
      reason: r.reason,
      context: r.context || null,
      note: typeof r.note === "string" ? r.note.slice(0, 500) : null,
    });
  }
);
