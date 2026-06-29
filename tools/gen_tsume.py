#!/usr/bin/env python3
"""
gen_tsume.py — 詰将棋ジェネレーター（著作権フリー）
アルゴリズムで詰将棋問題を生成し tsume_extra.json に追記する

使い方:
  python tools/gen_tsume.py              # 3手詰め × 10問
  python tools/gen_tsume.py -n 1 -c 30  # 1手詰め × 30問
  python tools/gen_tsume.py -n 5 -c 5   # 5手詰め × 5問
  python tools/gen_tsume.py -n 3 -c 20 --seed 42  # 再現可能な生成
"""

import argparse, json, os, random, sys

# ── 駒定数 ──────────────────────────────────────────────────────────────────
FU,KY,KE,GI,KI,KA,HI,OU = 1,2,3,4,5,6,7,8
TO,NY,NK,NG,UM,RY        = 9,10,11,12,13,14

CSA = {FU:'FU',KY:'KY',KE:'KE',GI:'GI',KI:'KI',KA:'KA',HI:'HI',OU:'OU',
       TO:'TO',NY:'NY',NK:'NK',NG:'NG',UM:'UM',RY:'RY'}

BASE = {TO:FU,NY:KY,NK:KE,NG:GI,UM:KA,RY:HI}  # 成り前
PROM = {FU:TO,KY:NY,KE:NK,GI:NG,KA:UM,HI:RY}  # 成り後
PROM_SET = set(PROM)

# 将棋標準の駒数上限（両者合計）
_PIECE_MAX = {FU:18, KY:4, KE:4, GI:4, KI:4, KA:2, HI:2}

def _valid_square(r, pt, pl):
    """その段に置けるか（香・桂の後段制限）"""
    if pt == KY: return not (pl == 1 and r == 0) and not (pl == 2 and r == 8)
    if pt == KE: return not (pl == 1 and r <= 1) and not (pl == 2 and r >= 7)
    return True

def _valid_board_placement(b):
    """盤面全駒の配置が合法か確認"""
    for r in range(9):
        for c in range(9):
            sq = b[r][c]
            if sq is None: continue
            pl, pt = sq
            if not _valid_square(r, pt, pl): return False
    return True

def _valid_piece_count(b, h1, h2):
    """盤上＋両者持ち駒の基本駒数が標準ルール内か確認"""
    c = {}
    for row in b:
        for sq in row:
            if sq is None: continue
            base = BASE.get(sq[1], sq[1])
            if base == OU: continue
            c[base] = c.get(base, 0) + 1
    for h in (h1, h2):
        for pt, n in h.items():
            base = BASE.get(pt, pt)
            c[base] = c.get(base, 0) + n
    return all(c.get(pt, 0) <= maxn for pt, maxn in _PIECE_MAX.items())

# ── 移動方向（P1視点: "前" = row-1）────────────────────────────────────────
_K8 = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
_G6 = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,0)]
_S5 = [(-1,-1),(-1,0),(-1,1),(1,-1),(1,1)]
_RDIR = [(-1,0),(1,0),(0,-1),(0,1)]
_BDIR = [(-1,-1),(-1,1),(1,-1),(1,1)]

_P1_STEP = {
    FU:[(-1,0)], KE:[(-2,-1),(-2,1)], GI:_S5, KI:_G6, OU:_K8,
    TO:_G6, NY:_G6, NK:_G6, NG:_G6,
}
# P2視点: 前後反転（列方向は変わらない）
_P2_STEP = {k:[(-r,c) for r,c in v] for k,v in _P1_STEP.items()}

# ── 利き・王手判定 ──────────────────────────────────────────────────────────
def _slider(b, r, c, dirs, pl):
    out = []
    for dr,dc in dirs:
        nr,nc = r+dr,c+dc
        while 0<=nr<9 and 0<=nc<9:
            sq = b[nr][nc]
            if sq is None:
                out.append((nr,nc))
            else:
                if sq[0]!=pl: out.append((nr,nc))
                break
            nr+=dr; nc+=dc
    return out

def attacks(b, r, c):
    """(r,c)の駒が移動できるマス → [(nr,nc)]"""
    sq = b[r][c]
    if sq is None: return []
    pl,pt = sq
    tab = _P1_STEP if pl==1 else _P2_STEP
    if pt in tab:
        return [(r+dr,c+dc) for dr,dc in tab[pt]
                if 0<=r+dr<9 and 0<=c+dc<9
                and (b[r+dr][c+dc] is None or b[r+dr][c+dc][0]!=pl)]
    if pt==KY:
        return _slider(b,r,c,[(-1,0) if pl==1 else (1,0)],pl)
    if pt==HI: return _slider(b,r,c,_RDIR,pl)
    if pt==KA: return _slider(b,r,c,_BDIR,pl)
    if pt==UM:
        res = set(_slider(b,r,c,_BDIR,pl))
        for dr,dc in _K8:
            nr,nc=r+dr,c+dc
            if 0<=nr<9 and 0<=nc<9 and (b[nr][nc] is None or b[nr][nc][0]!=pl):
                res.add((nr,nc))
        return list(res)
    if pt==RY:
        res = set(_slider(b,r,c,_RDIR,pl))
        for dr,dc in _K8:
            nr,nc=r+dr,c+dc
            if 0<=nr<9 and 0<=nc<9 and (b[nr][nc] is None or b[nr][nc][0]!=pl):
                res.add((nr,nc))
        return list(res)
    return []

def find_king(b, pl):
    for r in range(9):
        for c in range(9):
            if b[r][c]==(pl,OU): return r,c
    return None,None

def in_check(b, pl):
    kr,kc = find_king(b,pl)
    if kr is None: return False
    opp = 3-pl
    for r in range(9):
        for c in range(9):
            if b[r][c] is not None and b[r][c][0]==opp:
                if (kr,kc) in attacks(b,r,c): return True
    return False

# ── 合法手生成 ──────────────────────────────────────────────────────────────
# move = (fr, fc, tr, tc, promote:bool, drop:int|None)

def _must_promote(r, pt, pl):
    """この段にいると動けなくなるため成り強制"""
    if pt==FU or pt==KY: return (r==0 if pl==1 else r==8)
    if pt==KE:           return (r<=1 if pl==1 else r>=7)
    return False

def _in_promo_zone(r, pl):
    return r<=2 if pl==1 else r>=6

def _raw_board_moves(b, pl):
    raw = []
    for fr in range(9):
        for fc in range(9):
            sq = b[fr][fc]
            if sq is None or sq[0]!=pl: continue
            pt = sq[1]
            for tr,tc in attacks(b,fr,fc):
                must = _must_promote(tr,pt,pl)
                can  = (pt in PROM_SET) and (_in_promo_zone(fr,pl) or _in_promo_zone(tr,pl))
                if must:
                    raw.append((fr,fc,tr,tc,True,None))
                elif can:
                    raw.append((fr,fc,tr,tc,True,None))
                    raw.append((fr,fc,tr,tc,False,None))
                else:
                    raw.append((fr,fc,tr,tc,False,None))
    return raw

def _raw_drop_moves(b, h, pl):
    raw = []
    for pt,cnt in h.items():
        if cnt<=0: continue
        for tr in range(9):
            for tc in range(9):
                if b[tr][tc] is not None: continue
                if _must_promote(tr,pt,pl): continue  # 行けない段には打てない
                if pt==FU:
                    # 二歩チェック
                    if any(b[r][tc]==(pl,FU) for r in range(9)): continue
                raw.append((-1,-1,tr,tc,False,pt))
    return raw

def apply_move(b, h1, h2, m, pl):
    """move を pl 側として適用 → (new_board, new_h1, new_h2)"""
    fr,fc,tr,tc,prom,drop = m
    nb = [row[:] for row in b]
    nh1,nh2 = h1.copy(),h2.copy()
    if drop is not None:
        h = nh1 if pl==1 else nh2
        h[drop] = h.get(drop,0)-1
        nb[tr][tc] = (pl,drop)
    else:
        pt = nb[fr][fc][1]
        cap = nb[tr][tc]
        if cap is not None:
            base = BASE.get(cap[1],cap[1])
            if pl==1: nh1[base]=nh1.get(base,0)+1
            else:      nh2[base]=nh2.get(base,0)+1
        nb[fr][fc] = None
        nb[tr][tc] = (pl, PROM[pt] if prom and pt in PROM_SET else pt)
    return nb,nh1,nh2

def legal_moves(b, h1, h2, pl):
    """王手放置・打ち歩詰め除外済みの合法手"""
    h = h1 if pl==1 else h2
    raw = _raw_board_moves(b,pl) + _raw_drop_moves(b,h,pl)
    result = []
    opp = 3-pl
    for m in raw:
        nb,nh1,nh2 = apply_move(b,h1,h2,m,pl)
        if in_check(nb,pl): continue  # 王手放置禁止
        # 打ち歩詰め禁止（FUを打って相手を詰ます）
        if m[5]==FU and in_check(nb,opp):
            h_opp = nh2 if pl==1 else nh1
            opp_raw = _raw_board_moves(nb,opp)+_raw_drop_moves(nb,h_opp,opp)
            can_escape = any(
                not in_check(nb2,opp)
                for nb2,_,_ in (apply_move(nb,nh1,nh2,em,opp) for em in opp_raw)
            )
            if not can_escape: continue
        result.append(m)
    return result

# ── 詰み探索 ────────────────────────────────────────────────────────────────
def solve(b, h1, h2, depth, pl, nc, limit=120_000):
    """
    depth: 残り手数（半手）
    pl==1: P1の番（王手になる手のみ試す）
    pl==2: P2の番（全逃げ手を試す、全手で詰めば詰み）
    returns: 詰み手順 list[move] or None
    """
    nc[0]+=1
    if nc[0]>limit: return None

    if pl==2:
        escapes = legal_moves(b,h1,h2,2)
        if not escapes:
            return [] if in_check(b,2) else None  # 詰み or 不正局面
        if depth==0: return None                   # まだ逃げ手がある
        # 全逃げ手が詰むならば詰み確定
        best = None
        for m in escapes:
            nb,nh1,nh2 = apply_move(b,h1,h2,m,2)
            r = solve(nb,nh1,nh2,depth-1,1,nc,limit)
            if r is None: return None              # この逃げ手で逃げられる
            if best is None: best = [m]+r
        return best

    else:  # pl==1
        if depth==0: return None
        for m in legal_moves(b,h1,h2,1):
            nb,nh1,nh2 = apply_move(b,h1,h2,m,1)
            if not in_check(nb,2): continue        # 王手でなければスキップ（詰将棋ルール）
            r = solve(nb,nh1,nh2,depth-1,2,nc,limit)
            if r is not None:
                return [m]+r
        return None

# ── ランダム局面生成 ─────────────────────────────────────────────────────────
# P2玉の配置候補（端・角・中段まで多様化）
# 重み付けのため端・角は複数回登録
_P2_KING_SPOTS = [
    # 1段（最上段）
    (0,0),(0,0),(0,1),(0,2),(0,6),(0,7),(0,8),(0,8),
    # 2段
    (1,0),(1,0),(1,8),(1,8),
    # 3段
    (2,0),(2,8),(2,4),
    # 中段（3〜5段：多様性のため追加）
    (3,0),(3,8),(3,4),
    (4,0),(4,8),
    (5,0),(5,8),
]

def _gen_one(n_moves, rng):
    """詰将棋局面を1つ生成。失敗時はNone"""
    for _ in range(400):
        b = [[None]*9 for _ in range(9)]
        h1,h2 = {},{}
        used = set()

        # P2玉
        kr,kc = rng.choice(_P2_KING_SPOTS)
        b[kr][kc]=(2,OU); used.add((kr,kc))

        # P1玉（P2玉から遠い位置、かつ下段寄り）
        for _ in range(100):
            p1kr=rng.randint(max(kr+3,5),8); p1kc=rng.randint(0,8)
            if (p1kr,p1kc) not in used:
                b[p1kr][p1kc]=(1,OU); used.add((p1kr,p1kc)); break
        else:
            for _ in range(100):
                p1kr=rng.randint(5,8); p1kc=rng.randint(0,8)
                if (p1kr,p1kc) not in used:
                    b[p1kr][p1kc]=(1,OU); used.add((p1kr,p1kc)); break

        # 手数ごとのパラメータ（飛/竜偏重を緩和）
        if n_moves==1:
            pool=[KI,KA,GI,UM,RY,KE,KI,GI,KA,HI]  # 金銀角を増やし飛を抑制
            n_board=rng.randint(1,2); n_hand=rng.randint(0,1)
        elif n_moves==3:
            pool=[KI,GI,KA,UM,RY,KE,KI,GI,HI,KA]  # バランス化
            n_board=rng.randint(1,3); n_hand=rng.randint(0,2)
        else:  # 5手
            pool=[KI,GI,KA,RY,UM,KE,KY,FU,KI,GI,HI,KA]  # 幅広く
            n_board=rng.randint(2,4); n_hand=rng.randint(1,3)

        # P1攻め駒（盤上）
        for _ in range(n_board):
            pt=rng.choice(pool)
            for __ in range(60):
                r=rng.randint(max(0,kr-3),min(8,kr+3))
                c=rng.randint(max(0,kc-3),min(8,kc+3))
                if (r,c) not in used and _valid_square(r,pt,1):
                    b[r][c]=(1,pt); used.add((r,c)); break

        # P1持ち駒（成り駒は持ち駒に持てない）
        hand_pool = [p for p in pool if p not in {RY,UM,TO,NY,NK,NG}]
        for _ in range(n_hand):
            pt=rng.choice(hand_pool)
            h1[pt]=h1.get(pt,0)+1

        # P2受け駒（少数）
        n_def = rng.randint(0, 1 if n_moves<=3 else 2)
        for _ in range(n_def):
            pt2=rng.choice([FU,GI,KI,KE])
            for __ in range(30):
                r=rng.randint(max(0,kr-2),min(8,kr+2))
                c=rng.randint(max(0,kc-2),min(8,kc+2))
                if (r,c) not in used and _valid_square(r,pt2,2):
                    b[r][c]=(2,pt2); used.add((r,c)); break

        # バリデーション
        if not _valid_board_placement(b): continue  # 香・桂の配置不正 → 除外
        if in_check(b,2): continue      # 最初から王手 → 除外
        if in_check(b,1): continue      # P1が王手されている → 除外
        if not legal_moves(b,h1,h2,2): continue  # すでに詰んでいる → 除外
        if not _valid_piece_count(b,h1,h2): continue  # 駒枚数が標準ルール違反 → 除外

        # 詰み探索
        nc=[0]
        sol=solve(b,h1,h2,n_moves,1,nc)
        if sol is None or len(sol)!=n_moves: continue

        # より短い詰みがないか確認（全奇数短手数をチェック）
        if n_moves>=3:
            if any(solve(b,h1,h2,s,1,[0]) is not None for s in range(1,n_moves,2)):
                continue

        return b,h1,h2,sol
    return None

# ── JSON変換 ────────────────────────────────────────────────────────────────
def board_to_flat(b):
    return ['' if b[r][c] is None
            else ('+' if b[r][c][0]==1 else '-')+CSA[b[r][c][1]]
            for r in range(9) for c in range(9)]

def hand_to_dict(h):
    """アプリの parseHand(Map<String,dynamic>) 形式に合わせる"""
    return {CSA[pt]: n for pt,n in h.items() if n>0}

def move_to_dict(m, cur_board=None):
    fr,fc,tr,tc,prom,drop = m
    d = {'fr':fr,'fc':fc,'tr':tr,'tc':tc}
    if drop is not None:
        csa_code = CSA[drop]
        d['drop'] = csa_code
        d['piece'] = csa_code
    else:
        if cur_board is not None and cur_board[fr][fc] is not None:
            d['piece'] = CSA[cur_board[fr][fc][1]]
        if prom:
            d['promote'] = True
    return d

def make_entry(b, h1, h2, sol, pid, n_moves):
    diff = '初級' if n_moves<=2 else ('中級' if n_moves<=4 else '上級')
    sol_dicts = []
    cb = [row[:] for row in b]
    ch1, ch2 = h1.copy(), h2.copy()
    mover = 1
    for m in sol:
        sol_dicts.append(move_to_dict(m, cb))
        cb, ch1, ch2 = apply_move(cb, ch1, ch2, m, mover)
        mover = 3 - mover
    return {
        'id':       pid,
        'title':    f'{n_moves}手詰め',
        'difficulty': diff,
        'moves':    n_moves,
        'board':    board_to_flat(b),
        'p1Hand':   hand_to_dict(h1),
        'p2Hand':   hand_to_dict(h2),
        'solution': sol_dicts,
        'explanation': f'{n_moves}手詰めです。連続王手で玉を逃がさず詰ましましょう。',
    }

# ── メイン ──────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description='詰将棋ジェネレーター（著作権フリー）')
    ap.add_argument('-n','--moves',  type=int, default=3,
                    help='手数 1/3/5 (default: 3)')
    ap.add_argument('-c','--count',  type=int, default=10,
                    help='生成問題数 (default: 10)')
    ap.add_argument('-o','--output', default='assets/tsume_extra.json',
                    help='出力JSONファイル (default: assets/tsume_extra.json)')
    ap.add_argument('--seed', type=int, default=None,
                    help='乱数シード（再現可能な生成）')
    args = ap.parse_args()

    if args.moves%2==0:
        print('ERROR: 手数は奇数を指定してください (1, 3, 5, ...)'); sys.exit(1)
    if args.moves>5:
        print('WARNING: 7手以上は生成に時間がかかる場合があります')

    # 既存JSONを読み込む
    comment_entry = None
    existing = []
    if os.path.exists(args.output):
        with open(args.output,'r',encoding='utf-8') as f:
            data = json.load(f)
        for e in data:
            if '_comment' in e: comment_entry=e
            elif 'id' in e: existing.append(e)

    existing_ids = {e['id'] for e in existing}
    rng = random.Random(args.seed)
    generated = []
    attempts = 0

    print(f'{args.moves}手詰め × {args.count}問を生成中 ...')

    while len(generated)<args.count:
        attempts+=1
        if attempts>args.count*300:
            print(f'  警告: 上限試行回数に達しました ({len(generated)}問生成済み)')
            break
        if attempts%200==0:
            print(f'  試行 {attempts}回 / {len(generated)}問生成済み ...',flush=True)

        result = _gen_one(args.moves, rng)
        if result is None: continue

        b,h1,h2,sol = result
        pid = f'gen_{args.moves}m_{len(existing)+len(generated)+1:04d}'
        if pid in existing_ids: continue

        entry = make_entry(b,h1,h2,sol,pid,args.moves)
        generated.append(entry)
        print(f'  [{len(generated)}/{args.count}] {pid}  '
              f'(試行:{attempts} / P1手:{hand_to_dict(h1)} / P2手:{hand_to_dict(h2)})',
              flush=True)

    # 書き出し
    output = []
    if comment_entry: output.append(comment_entry)
    output.extend(existing)
    output.extend(generated)

    out_dir = os.path.dirname(args.output)
    if out_dir: os.makedirs(out_dir, exist_ok=True)
    with open(args.output,'w',encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f'\n[OK] {len(generated)}問を追記 -> {args.output}')
    print(f'  合計 {len(output)-(1 if comment_entry else 0)}問')

if __name__=='__main__':
    main()
