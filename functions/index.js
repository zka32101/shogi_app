'use strict';
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

// YaneuraOu 将棋エンジン
const YaneuraOu = require('@mizarjp/yaneuraou.halfkp');
let engine = null;

// エンジン初期化（遅延ロード）
async function getEngine() {
  if (engine) return engine;
  engine = new YaneuraOu();
  await engine.isReady();
  return engine;
}

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

// ── HTTP API: ユーザー統計取得 ──────────────────────────────
exports.getUserStatistics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  try {
    const usersSnap = await db.collection('users').get();

    // レーティング帯別に集計
    const distribution = {
      '0-499': 0,      // 初心者
      '500-599': 0,    // 級位下
      '600-699': 0,    // 級位中
      '700-799': 0,    // 級位上
      '800-899': 0,    // 段位下
      '900-999': 0,    // 段位中
      '1000+': 0,      // 段位上
    };

    let totalRating = 0;
    let totalUsers = 0;
    let maxRating = 0;
    let minRating = 10000;

    usersSnap.forEach((doc) => {
      const user = doc.data();
      const rating = user.rating || 700;

      totalRating += rating;
      totalUsers += 1;
      maxRating = Math.max(maxRating, rating);
      minRating = Math.min(minRating, rating);

      // 分布に追加
      if (rating < 500) distribution['0-499']++;
      else if (rating < 600) distribution['500-599']++;
      else if (rating < 700) distribution['600-699']++;
      else if (rating < 800) distribution['700-799']++;
      else if (rating < 900) distribution['800-899']++;
      else if (rating < 1000) distribution['900-999']++;
      else distribution['1000+']++;
    });

    const avgRating = totalUsers > 0 ? Math.round(totalRating / totalUsers) : 0;

    return {
      success: true,
      distribution,
      totalUsers,
      avgRating,
      maxRating: maxRating === 10000 ? 700 : maxRating,
      minRating: minRating === 10000 ? 700 : minRating,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (e) {
    console.error('getUserStatistics failed:', e);
    throw new functions.https.HttpsError('internal', '統計取得に失敗しました');
  }
});

// ── HTTP API: 手筋評価（Yoneura/YaneuraOu） ──────────────────
exports.evaluateTesuji = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
  }

  const { sfen, depth = 20 } = data;
  if (!sfen) {
    throw new functions.https.HttpsError('invalid-argument', 'sfen が必要です');
  }

  try {
    const eng = await getEngine();

    // 盤面をセット
    eng.position(sfen);

    // 評価を実行（depth手先まで）
    const result = await new Promise((resolve, reject) => {
      const info = {};
      eng.go({ depth }, (line) => {
        // USI エンジンの info 行をパース
        if (line.startsWith('info')) {
          const match = line.match(/score cp (-?\d+)/);
          if (match) info.score = parseInt(match[1]);

          const moveMatch = line.match(/pv (.+?)(?:\s|$)/);
          if (moveMatch) info.bestMove = moveMatch[1];
        }
        // bestmove 行で終了
        if (line.startsWith('bestmove')) {
          const parts = line.split(' ');
          resolve({
            bestMove: parts[1],
            score: info.score || 0,
          });
        }
      });
    });

    // スコアから勝率を推定（ロジスティック関数）
    const winRate = Math.round(
      (1 / (1 + Math.exp(-result.score / 200))) * 100
    );

    return {
      success: true,
      bestMove: result.bestMove,
      score: result.score,
      winRate: winRate,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (e) {
    console.error('evaluateTesuji failed:', e);
    throw new functions.https.HttpsError('internal', '評価に失敗しました');
  }
});

// ── Schedule 1: マッチメイキング（毎3秒）──────────────────────
exports.matchmaking = functions.pubsub
  .schedule('every 3 seconds')
  .onRun(async (_ctx) => {
    try {
      const queueSnap = await db.collection('matching_queue')
        .where('status', '==', 'waiting')
        .orderBy('created_at', 'asc')
        .limit(100)
        .get();

      if (queueSnap.size < 2) return null;

      const players = queueSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      const matched = [];

      for (let i = 0; i < players.length - 1; i++) {
        if (matched.includes(players[i].id)) continue;
        const p1 = players[i];

        // 同じレーティング帯のプレイヤーを探索（±200範囲）
        for (let j = i + 1; j < players.length; j++) {
          if (matched.includes(players[j].id)) continue;
          const p2 = players[j];
          const ratingDiff = Math.abs((p1.rating || 700) - (p2.rating || 700));

          if (ratingDiff <= 200) {
            // マッチング成立 → matches に新規作成
            const matchRef = db.collection('matches').doc();
            await db.runTransaction(async (tx) => {
              tx.set(matchRef, {
                player1_id:  p1.id,
                player2_id:  p2.id,
                status:      'matched',
                created_at:  admin.firestore.FieldValue.serverTimestamp(),
                handicap:    null,
              });
              tx.update(db.collection('matching_queue').doc(p1.id), {
                status: 'matched',
                match_id: matchRef.id,
              });
              tx.update(db.collection('matching_queue').doc(p2.id), {
                status: 'matched',
                match_id: matchRef.id,
              });
            });
            matched.push(p1.id, p2.id);
            break;
          }
        }
      }

      console.log(`Matched ${matched.length / 2} pairs from ${players.length} waiting players`);
    } catch (e) {
      console.error('matchmaking failed:', e);
    }
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

// ── Schedule 4: デイリー問題生成（毎日 20:00 JST）──────────────
exports.generateDailyProblems = functions.pubsub
  .schedule('0 11 * * *')  // 20:00 JST = 11:00 UTC
  .timeZone('UTC')
  .onRun(async (_ctx) => {
    try {
      const today = new Date().toISOString().split('T')[0];
      const bucket = admin.storage().bucket();

      // 既に今日の問題が生成済みの場合はスキップ
      const alreadyExists = await bucket.file(`problems/${today}.json`).exists();
      if (alreadyExists[0]) {
        console.log(`Problems already generated for ${today}`);
        return null;
      }

      // SFEN プールからランダムに 5個を選択（簡易版）
      const sfenPool = _getSfenPool();
      const problems = [];
      const usedIndices = new Set();

      // ランダムに 5問を生成
      for (let i = 0; i < 5; i++) {
        let randomIdx;
        do {
          randomIdx = Math.floor(Math.random() * sfenPool.length);
        } while (usedIndices.has(randomIdx));
        usedIndices.add(randomIdx);

        const sfen = sfenPool[randomIdx];
        const problem = _generateProblem(sfen, i + 1, today);
        if (problem) {
          problems.push(problem);
        }
      }

      if (problems.length === 0) {
        console.error('Failed to generate any problems');
        return null;
      }

      // Cloud Storage に JSON を保存
      const jsonStr = JSON.stringify(problems, null, 2);
      await bucket.file(`problems/${today}.json`).save(jsonStr, {
        contentType: 'application/json',
        metadata: {
          cacheControl: 'public, max-age=86400',
        },
      });

      // Firestore にメタデータを記録
      await db.collection('daily_problems').doc(today).set({
        problemIds: problems.map((p) => p.id),
        count: problems.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'auto-generated',
      });

      console.log(`Generated ${problems.length} problems for ${today}`);
      return null;
    } catch (e) {
      console.error('generateDailyProblems failed:', e);
      throw e;
    }
  });

/**
 * SFEN プール（手筋・詰将棋の基本的な 100+ 局面）
 * 実運用では bookminer や棋力検定からの抽出 SFEN を使用
 */
function _getSfenPool() {
  // 基本的な詰将棋・手筋 SFEN（簡易版）
  return [
    // 3手詰（初級）
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
    'ln1gkgsnl/1r6b/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b P 1',

    // 飛車取り
    '7k1/6r2/8p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL b - 1',
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/3P5/PPP1PPPPP/1B5R1/LNSGKGSNL w - 1',

    // 王手金取り
    'lnsgkgsnl/1r5b1/ppppppppp/9/2P6/9/PP1PPPPPP/1B5R1/LNSGKGSNL w - 1',
    '7k1/6r2/4g3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 両取り
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/3B5/PPPPPPPPP/1R6R/LNSGKGSNL b - 1',
    '8k/6r2/4n3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 駒が取れる
    '6nk1/6r2/4r3p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
    'ln1gkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',

    // 詰将棋パターン
    '8k/7P1/8K/9/9/9/9/9/9 b - 1',
    '8k/6P1/8K/9/9/9/9/9/9 b - 1',
    '6n1k/6r2/8p/5P1P/9/9/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',

    // 基本詰め
    '6nk1/6r2/8p/5P1P/9/8K/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
    '8k/6r2/9/5P1P/9/8K/PPPPPP1PP/1B5R1/LNSGKGSNL w - 1',
  ];
}

/**
 * SFEN から問題を生成（簡易版）
 * 本番では problem_generator.dart をポートした TypeScript 版を使用
 */
function _generateProblem(sfen, index, dateStr) {
  try {
    // 簡易的な難度判定（SFEN の長さで仮判定）
    const difficulty = sfen.length < 50 ? '初級' : sfen.length < 70 ? '中級' : '上級';

    return {
      id: `daily_${dateStr}_${index}`,
      title: `${difficulty} 詰将棋 ${index}`,
      category: '詰め',
      difficulty,
      board: sfen,
      p1_hand: {},
      p2_hand: {},
      p1_turn: true,
      answer: {
        fr: 0,
        fc: 0,
        tr: 1,
        tc: 1,
        drop: null,
        promote: false,
      },
      explanation: `詰将棋問題です。${difficulty}の難易度でお試しください。`,
      source_url: null,
      source_title: 'Auto-generated',
    };
  } catch (e) {
    console.error(`Failed to generate problem for SFEN: ${sfen}`, e);
    return null;
  }
}
