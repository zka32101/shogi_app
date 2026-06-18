#!/usr/bin/env python3
"""
convert_tsume.py — KIF/CSA 形式の詰将棋ファイルを
shogi_app の assets/tsume_extra.json に変換するスクリプト。

使い方:
  python tools/convert_tsume.py problems/            # フォルダ内の全 .kif/.csa ファイル
  python tools/convert_tsume.py problem.kif          # 単一ファイル
  python tools/convert_tsume.py --check              # 既存の tsume_extra.json を検証

出力:
  assets/tsume_extra.json に追記（重複タイトルはスキップ）

KIF フォーマット例:
  手合割：その他
  先手の持駒：金
  後手の持駒：なし
    ９ ８ ７ ６ ５ ４ ３ ２ １
  +---------------------------+
  |v玉 ・ ・ ・ ・ ・ ・ ・ ・|一
  | ・ ・ ・ ・ ・ ・金 ・ ・|二
  ...
  後手番 (または先手番)
  変化：N手
     1 ２二金打
     2 同　玉
  ...

CSA フォーマット例 (簡略版):
  P1-KY-KE...
  P2...
  P+00KI (先手持駒: 金)
  P-     (後手持駒: なし)
  +      (先手番)
  +2221KI
  -1112OU
  ...
"""

import sys
import json
import re
import os
from pathlib import Path

# ── 定数 ──────────────────────────────────────────────────
OUTPUT_PATH = Path(__file__).parent.parent / "assets" / "tsume_extra.json"

# KIF の駒文字 → CSA コード
KIF_TO_CSA = {
    "王": "OU", "玉": "OU",
    "飛": "HI", "竜": "RY", "龍": "RY",
    "角": "KA", "馬": "UM",
    "金": "KI",
    "銀": "GI", "全": "NG",
    "桂": "KE", "圭": "NK",
    "香": "KY", "杏": "NY",
    "歩": "FU", "と": "TO",
}

# 段数テキスト → row インデックス（0始まり）
RANK_TO_ROW = {"一": 0, "二": 1, "三": 2, "四": 3, "五": 4,
               "六": 5, "七": 6, "八": 7, "九": 8}

# 筋数字 → col インデックス（col=0が9筋右端, col=8が1筋左端）
FILE_TO_COL = {str(9 - i): i for i in range(9)}  # "9"→0, "8"→1, ..., "1"→8
FILE_TO_COL.update({"９": 0, "８": 1, "７": 2, "６": 3, "５": 4,
                    "４": 5, "３": 6, "２": 7, "１": 8})


def empty_board():
    return [""] * 81


def board_idx(row, col):
    return row * 9 + col


# ── KIF パーサ ────────────────────────────────────────────

def parse_kif_piece_char(ch, promoted=False):
    """KIF の駒文字を CSA コードに変換。v/+ で成りを判断。"""
    base = KIF_TO_CSA.get(ch)
    if base is None:
        return None
    if promoted and base in ("HI", "KA", "GI", "KE", "KY", "FU"):
        promo_map = {"HI": "RY", "KA": "UM", "GI": "NG", "KE": "NK", "KY": "NY", "FU": "TO"}
        base = promo_map.get(base, base)
    return base


def parse_kif_board_line(line, row):
    """
    KIF の盤面行 "|v玉 ・ ・金 ・ ・ ・ ・ ・|一" を解析。
    戻り値: [(col, is_p1, csa_code), ...]
    """
    result = []
    # | と | の間の部分を取得
    m = re.match(r"\|(.+)\|", line)
    if not m:
        return result
    inner = m.group(1)
    # 各マス: 2文字または3文字（v + 駒 + スペース or ・+スペース）
    # KIF の盤面は 9筋(左)→1筋(右)の順で表示（col=0が左=9筋）
    cells = re.findall(r"(v[^・\s]+|[+]?[^v・\s]+|・)", inner)
    # 文字数ベースで解析
    col = 0
    i = 0
    raw = inner
    pos = 0
    while pos < len(raw) and col < 9:
        if raw[pos] == "・":
            col += 1
            pos += 1
            if pos < len(raw) and raw[pos] == " ":
                pos += 1
        elif raw[pos] == "v":
            # 後手駒
            pos += 1
            piece_char = raw[pos] if pos < len(raw) else ""
            pos += 1
            promoted = False
            if pos < len(raw) and raw[pos] in ("竜", "龍", "馬", "全", "圭", "杏", "と"):
                promoted = True
            code = parse_kif_piece_char(piece_char, promoted)
            if code:
                result.append((col, False, code))
            col += 1
            if pos < len(raw) and raw[pos] == " ":
                pos += 1
        elif raw[pos] == "+":
            # 成り駒（先手）
            pos += 1
            piece_char = raw[pos] if pos < len(raw) else ""
            pos += 1
            code = parse_kif_piece_char(piece_char, True)
            if code:
                result.append((col, True, code))
            col += 1
            if pos < len(raw) and raw[pos] == " ":
                pos += 1
        else:
            # 先手駒（普通）
            piece_char = raw[pos]
            pos += 1
            # 成り2文字駒（竜、馬等）をチェック
            if pos < len(raw) and raw[pos] in ("竜", "龍", "馬", "全", "圭", "杏", "と"):
                piece_char = raw[pos]
                pos += 1
                code = parse_kif_piece_char(piece_char, False)
            else:
                code = parse_kif_piece_char(piece_char, False)
            if code:
                result.append((col, True, code))
            col += 1
            if pos < len(raw) and raw[pos] == " ":
                pos += 1
    return result


def parse_kif_hand(line):
    """
    "先手の持駒：金 銀二 桂三" → {"KI": 1, "GI": 2, "KE": 3}
    """
    result = {}
    # コロンの後ろを取得
    m = re.search(r"[：:](.*)", line)
    if not m:
        return result
    hand_str = m.group(1).strip()
    if not hand_str or hand_str in ("なし", ""):
        return result
    # "金", "銀二", "飛三" 等のパターン
    for match in re.finditer(r"([王玉飛竜龍角馬金銀全桂圭香杏歩と])([二三四五六七八九]|\d+)?", hand_str):
        piece_char = match.group(1)
        count_str = match.group(2)
        code = KIF_TO_CSA.get(piece_char)
        if not code:
            continue
        count_map = {"二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}
        count = count_map.get(count_str, int(count_str) if count_str and count_str.isdigit() else 1)
        result[code] = result.get(code, 0) + count
    return result


def parse_kif_move(move_str, board_state):
    """
    KIF の指し手テキスト "２二金打" や "同　玉" → AMove dict
    board_state: 現在の盤面状態（同の処理用）
    """
    move_str = move_str.strip()
    # 投了・中断等は None
    if any(kw in move_str for kw in ("投了", "中断", "詰み", "千日手", "持将棋")):
        return None

    result = {"fr": -1, "fc": -1, "tr": -1, "tc": -1}

    # 行き先の座標（例: ２二 → file=2, rank=二 → row=1, col=7）
    dest_match = re.match(r"([１-９1-9]|同)([一二三四五六七八九]?)", move_str)
    if not dest_match:
        return None

    if dest_match.group(1) == "同":
        # 「同」は前の手と同じマス — caller が前の to 座標を渡す必要があるが今は skip
        tr = board_state.get("last_tr", -1)
        tc = board_state.get("last_tc", -1)
        if tr < 0:
            return None
    else:
        file_char = dest_match.group(1)
        rank_char = dest_match.group(2)
        tc = FILE_TO_COL.get(file_char, -1)
        tr = RANK_TO_ROW.get(rank_char, -1)
        if tc < 0 or tr < 0:
            return None

    result["tr"] = tr
    result["tc"] = tc

    # 残り部分から駒種・打ち/移動・成りを判断
    rest = move_str[dest_match.end():]

    # 打ち
    if "打" in rest:
        piece_match = re.search(r"([王玉飛竜龍角馬金銀全桂圭香杏歩と])", move_str)
        if piece_match:
            code = KIF_TO_CSA.get(piece_match.group(1))
            if code:
                result["drop"] = code
        return result

    # 成り
    if "成" in rest and "不成" not in rest:
        result["promote"] = True

    # 移動元座標（例: (31)）
    from_match = re.search(r"\((\d)(\d)\)", rest)
    if from_match:
        from_file = from_match.group(1)  # 1-9
        from_rank = from_match.group(2)  # 1-9
        fc = FILE_TO_COL.get(from_file, -1)
        fr = int(from_rank) - 1  # rank1=row0
        result["fr"] = fr
        result["fc"] = fc

    return result


def parse_kif_file(filepath):
    """KIF ファイルを解析して問題データを返す。失敗時は None。"""
    try:
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            lines = f.readlines()
    except Exception as e:
        print(f"  [ERROR] 読み込み失敗: {e}")
        return None

    board = empty_board()
    p1_hand = {}
    p2_hand = {}
    in_board = False
    row = 0
    moves_text = []
    move_count = None
    title = Path(filepath).stem  # ファイル名をデフォルトタイトルに

    for line in lines:
        line = line.rstrip("\n\r")

        # タイトル・手数
        if "変化：" in line or "手数=" in line:
            m = re.search(r"(\d+)手", line)
            if m:
                move_count = int(m.group(1))

        # タイトル行
        if line.startswith("# ") or "：" in line and "タイトル" in line:
            title = re.sub(r"[タイトル：]", "", line).strip() or title

        # 持駒
        if "先手の持駒" in line or "上手の持駒" in line:
            p1_hand = parse_kif_hand(line)
        elif "後手の持駒" in line or "下手の持駒" in line:
            p2_hand = parse_kif_hand(line)

        # 盤面開始/終了
        if line.startswith("+--"):
            if not in_board:
                in_board = True
                row = 0
            else:
                in_board = False
        elif in_board and line.startswith("|"):
            pieces = parse_kif_board_line(line, row)
            for (col, is_p1, code) in pieces:
                board[board_idx(row, col)] = ("+" if is_p1 else "-") + code
            row += 1

        # 指し手行 ( "   1 ２二金打" 形式)
        m = re.match(r"\s*(\d+)\s+(.+)", line)
        if m:
            moves_text.append(m.group(2).strip())

    if not any(board):
        return None  # 盤面なし

    # 指し手をパース
    solution = []
    board_state = {}
    for move_str in moves_text:
        mv = parse_kif_move(move_str, board_state)
        if mv is None:
            break
        solution.append(mv)
        if mv["tr"] >= 0:
            board_state["last_tr"] = mv["tr"]
            board_state["last_tc"] = mv["tc"]

    if move_count is None:
        move_count = (len(solution) + 1) // 2  # 奇数手 = 先手の手数

    moves_label = move_count

    return {
        "title": f"{moves_label}手詰め（{title}）",
        "moves": moves_label,
        "board": board,
        "p1Hand": p1_hand,
        "p2Hand": p2_hand,
        "solution": solution,
        "explanation": "",
    }


# ── CSA パーサ ────────────────────────────────────────────

CSA_ROW = {str(i): i - 1 for i in range(1, 10)}
CSA_COL = {str(i): 9 - i for i in range(1, 10)}  # file1→col8, file9→col0


def parse_csa_file(filepath):
    """CSA ファイルを解析して問題データを返す。失敗時は None。"""
    try:
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            lines = f.readlines()
    except Exception as e:
        print(f"  [ERROR] 読み込み失敗: {e}")
        return None

    board = empty_board()
    p1_hand = {}
    p2_hand = {}
    solution = []
    title = Path(filepath).stem
    current_player = "+"  # 先手番がデフォルト

    for line in lines:
        line = line.rstrip("\n\r").strip()
        if not line or line.startswith("'"):
            # コメント行からタイトルを取得
            if line.startswith("'"):
                title = line[1:].strip() or title
            continue

        # 盤面行: P1～P9
        m = re.match(r"P([1-9])(.*)", line)
        if m:
            row = int(m.group(1)) - 1
            cells_str = m.group(2)
            # 各マス: " * " or "+XX" or "-XX" (3文字ずつ)
            for col_idx, i in enumerate(range(0, len(cells_str), 3)):
                cell = cells_str[i:i+3].strip()
                if not cell or cell == "*":
                    continue
                sign = cell[0]
                code = cell[1:]
                if code not in ("OU", "HI", "KA", "KI", "GI", "KE", "KY", "FU",
                                "RY", "UM", "NG", "NK", "NY", "TO"):
                    continue
                # CSA: col_idx=0が9筋(file9)=col0
                col = col_idx
                board[board_idx(row, col)] = sign + code
            continue

        # 持駒行: P+00XX or P-00XX
        if line.startswith("P+") or line.startswith("P-"):
            sign = line[1]
            hand = p1_hand if sign == "+" else p2_hand
            for m2 in re.finditer(r"00([A-Z]{2})", line):
                code = m2.group(1)
                hand[code] = hand.get(code, 0) + 1
            continue

        # 手番: + or -
        if line == "+" or line == "-":
            current_player = line
            continue

        # 指し手: +7776FU or -8384FU
        m = re.match(r"([+-])(\d)(\d)(\d)(\d)([A-Z]{2})", line)
        if m:
            sign, ff, fr_rank, tf, tr_rank, code = m.groups()
            fc = CSA_COL.get(ff, -1)
            fr = CSA_ROW.get(fr_rank, -1)
            tc = CSA_COL.get(tf, -1)
            tr = CSA_ROW.get(tr_rank, -1)
            is_drop = (ff == "0" and fr_rank == "0")
            mv = {"fr": -1 if is_drop else fr,
                  "fc": -1 if is_drop else fc,
                  "tr": tr, "tc": tc}
            if is_drop:
                mv["drop"] = code
            solution.append(mv)
            continue

    if not any(board):
        return None

    move_count = (len(solution) + 1) // 2

    return {
        "title": f"{move_count}手詰め（{title}）",
        "moves": move_count,
        "board": board,
        "p1Hand": p1_hand,
        "p2Hand": p2_hand,
        "solution": solution,
        "explanation": "",
    }


# ── 検証ロジック ──────────────────────────────────────────

def validate_problem(prob):
    """
    基本的な検証。エラーがあれば理由のリストを返す。
    """
    errors = []
    board = prob.get("board", [])
    if len(board) != 81:
        errors.append("board の要素数が 81 ではない")
        return errors

    # 後手玉の存在確認
    has_p2_king = any(c == "-OU" for c in board)
    has_p1_king = any(c == "+OU" for c in board)
    if not has_p2_king:
        errors.append("後手玉 (-OU) が盤面に存在しない")
    if not has_p1_king:
        errors.append("先手玉 (+OU) が盤面に存在しない")

    # 手数と指し手数の整合
    sol_len = len(prob.get("solution", []))
    expected_p1_moves = prob.get("moves", 0)
    if sol_len < expected_p1_moves * 2 - 1:
        errors.append(
            f"solution の手数 {sol_len} が moves={expected_p1_moves} に対して少ない"
            f" (最低 {expected_p1_moves * 2 - 1} 手必要)"
        )

    return errors


# ── メイン ────────────────────────────────────────────────

def load_existing(output_path):
    if not output_path.exists():
        return []
    with open(output_path, encoding="utf-8") as f:
        data = json.load(f)
    return [p for p in data if isinstance(p, dict) and "board" in p]


def save(problems, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(problems, f, ensure_ascii=False, indent=2)
    print(f"\n✓ {output_path} に {len(problems)} 問を保存しました")


def convert_file(filepath):
    ext = Path(filepath).suffix.lower()
    if ext == ".kif":
        return parse_kif_file(filepath)
    elif ext == ".csa":
        return parse_csa_file(filepath)
    else:
        print(f"  [SKIP] 未対応形式: {ext}")
        return None


def check_mode(output_path):
    """既存の tsume_extra.json を検証する。"""
    problems = load_existing(output_path)
    print(f"=== 検証: {output_path} ({len(problems)} 問) ===")
    ok = 0
    for i, p in enumerate(problems):
        errs = validate_problem(p)
        title = p.get("title", f"問題{i+1}")
        if errs:
            print(f"  [NG] {title}: {', '.join(errs)}")
        else:
            ok += 1
    print(f"\n結果: {ok}/{len(problems)} 問が基本検証OK")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(0)

    if "--check" in args:
        check_mode(OUTPUT_PATH)
        return

    # 既存の問題を読み込み
    existing = load_existing(OUTPUT_PATH)
    existing_titles = {p.get("title", "") for p in existing}

    files = []
    for arg in args:
        p = Path(arg)
        if p.is_dir():
            files.extend(p.glob("*.kif"))
            files.extend(p.glob("*.KIF"))
            files.extend(p.glob("*.csa"))
            files.extend(p.glob("*.CSA"))
        elif p.is_file():
            files.append(p)

    if not files:
        print("対象ファイルが見つかりません")
        sys.exit(1)

    added = 0
    skipped = 0
    errors = 0

    for filepath in sorted(files):
        print(f"変換中: {filepath.name} ...", end=" ")
        prob = convert_file(filepath)
        if prob is None:
            print("[FAIL]")
            errors += 1
            continue

        errs = validate_problem(prob)
        if errs:
            print(f"[NG] {', '.join(errs)}")
            errors += 1
            continue

        title = prob["title"]
        if title in existing_titles:
            print(f"[SKIP] 重複: {title}")
            skipped += 1
            continue

        existing.append(prob)
        existing_titles.add(title)
        print(f"[OK] {title} ({prob['moves']}手)")
        added += 1

    print(f"\n追加: {added} 問 / スキップ: {skipped} 問 / エラー: {errors} 問")

    if added > 0:
        save(existing, OUTPUT_PATH)
    else:
        print("追加問題なし。ファイルは変更しません。")


if __name__ == "__main__":
    main()
