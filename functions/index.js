'use strict';
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

// ── ELO計算 ─────────────────────────────────────────────────────
function calcElo(winnerRating, loserRating, kFactor = 32) {
  const expected = 1 / (1 + Math.pow(10, (loserRating - winnerRating) / 400));
  const winnerDelta = Math.round(kFactor * (1 - expected));
  const loserDelta  = Math.round(kFactor * (0 - (1 - expected)));
  return { winnerDelta, loserDelta };
}

// ── Trigger 1: 対局終了時 → ELO更新（Firestoreトリガー）────────
exports.onMatchFinished = functions.firestore
  .document('matches/{matchId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // status が 'finished' に変わったときだけ処理
    if (before.status === 'finished' || after.status !== 'finished') return null;
    // 二重実行防止フラグ
    if (after.rating_updated === true) return null;

    const matchId  = context.params.matchId;
    const winnerId = after.winner_id;
    const result   = after.result;
    const p1Id     = after.player1_id;
    const p2Id     = after.player2_id;

    // 引き分けはレーティング変動なし
    if (!winnerId || result === 'draw') {
      await change.after.ref.update({ rating_updated: true });
      return null;
    }

    const loserId = winnerId === p1Id ? p2Id : p1Id;

    try {
      await db.runTransaction(async (tx) => {
        const winnerRef = db.collection('users').doc(winnerId);
        const loserRef  = db.collection('users').doc(loserId);
        const [winnerDoc, loserDoc] = await Promise.all([
          tx.get(winnerRef),
          tx.get(loserRef),
        ]);

        if (!winnerDoc.exists || !loserDoc.exists) return;

        const winnerRating = winnerDoc.data().rating || 700;
        const loserRating  = loserDoc.data().rating  || 700;
        const { winnerDelta, loserDelta } = calcElo(winnerRating, loserRating);

        tx.update(winnerRef, {
          rating: admin.firestore.FieldValue.increment(winnerDelta),
          wins:   admin.firestore.FieldValue.increment(1),
        });
        tx.update(loserRef, {
          rating:  admin.firestore.FieldValue.increment(loserDelta),
          losses:  admin.firestore.FieldValue.increment(1),
        });
        tx.update(change.after.ref, {
          rating_updated:      true,
          winner_rating_delta: winnerDelta,
          loser_rating_delta:  loserDelta,
        });
      });
    } catch (e) {
      console.error(`ELO update failed for match ${matchId}:`, e);
    }

    // RTDB のゲームデータを削除（対局終了後は不要）
    try {
      await rtdb.ref(`games/${matchId}`).remove();
    } catch (_) {}

    return null;
  });

// ── Schedule 2: タイムアウト検知（毎分）────────────────────────
exports.checkTimeouts = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (_ctx) => {
    const now = Date.now();

    let gamesSnap;
    try {
      gamesSnap = await rtdb.ref('games')
        .orderByChild('status')
        .equalTo('active')
        .once('value');
    } catch (e) {
      console.error('checkTimeouts: RTDB read failed', e);
      return null;
    }

    if (!gamesSnap.exists()) return null;

    const rtdbUpdates = {};
    const firestoreJobs = [];

    gamesSnap.forEach((child) => {
      const game    = child.val();
      const matchId = child.key;
      if (!game || !game.clock) return;

      const { p1_ms, p2_ms, last_tick_ms, last_turn } = game.clock;
      const elapsed = now - (last_tick_ms || now);

      let timedOutSide = null; // 'p1' | 'p2' (負けた側)
      if (last_turn === 1 && p1_ms - elapsed <= 0) timedOutSide = 'p1';
      else if (last_turn === 2 && p2_ms - elapsed <= 0) timedOutSide = 'p2';

      if (!timedOutSide) return;

      const winnerId = timedOutSide === 'p1'
        ? game.player2_id
        : game.player1_id;

      rtdbUpdates[`games/${matchId}/status`]   = 'finished';
      rtdbUpdates[`games/${matchId}/result`]   = 'timeout';
      rtdbUpdates[`games/${matchId}/winner_id`] = winnerId || null;

      firestoreJobs.push(
        db.collection('matches').doc(matchId).update({
          status:      'finished',
          result:      'timeout',
          winner_id:   winnerId || null,
          finished_at: admin.firestore.FieldValue.serverTimestamp(),
        }).catch((e) => console.error(`Firestore update failed for ${matchId}:`, e))
      );
    });

    if (Object.keys(rtdbUpdates).length > 0) {
      await rtdb.ref().update(rtdbUpdates).catch(console.error);
      await Promise.all(firestoreJobs);
    }

    return null;
  });

// ── Schedule 3: 古いエントリのクリーンアップ（毎5分）────────────
exports.cleanupStale = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (_ctx) => {
    const nowSec = Math.floor(Date.now() / 1000);
    const cutoff = new admin.firestore.Timestamp(nowSec - 600, 0); // 10分前

    // Firestore: 待機中のマッチングキューを期限切れに
    try {
      const staleSnap = await db.collection('matching_queue')
        .where('status', '==', 'waiting')
        .where('created_at', '<', cutoff)
        .limit(100)
        .get();

      if (!staleSnap.empty) {
        const batch = db.batch();
        staleSnap.docs.forEach((doc) => batch.update(doc.ref, { status: 'expired' }));
        await batch.commit();
        console.log(`Expired ${staleSnap.size} stale queue entries`);
      }
    } catch (e) {
      console.error('cleanupStale: queue cleanup failed', e);
    }

    // RTDB: 30分間動きのない active ゲームを abandoned に
    const rtdbCutoff = Date.now() - 30 * 60 * 1000;
    try {
      const abandonedSnap = await rtdb.ref('games')
        .orderByChild('status')
        .equalTo('active')
        .once('value');

      if (!abandonedSnap.exists()) return null;

      const updates = {};
      abandonedSnap.forEach((child) => {
        const game         = child.val();
        const lastActivity = game.last_activity_ms || 0;
        if (lastActivity < rtdbCutoff) {
          updates[`games/${child.key}/status`] = 'abandoned';
        }
      });

      if (Object.keys(updates).length > 0) {
        await rtdb.ref().update(updates);
        console.log(`Abandoned ${Object.keys(updates).length} stale games`);
      }
    } catch (e) {
      console.error('cleanupStale: RTDB cleanup failed', e);
    }

    return null;
  });
