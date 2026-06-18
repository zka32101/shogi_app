#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tesuji_screen.dart の 55問に sourceUrl/sourceTitle を一括追加するスクリプト
"""

import re
import sys

# 修正ルール
SOURCE_MAPPING = {
    '飛車取り': {
        'sourceUrl': 'https://xn--pet04dr1n5x9a.com/tesuji/',
        'sourceTitle': '将棋講座.com',
    },
    '王手金取り': {
        'sourceUrl': 'https://www.shougi.jp/learn/tesuji/',
        'sourceTitle': '将棋研究',
    },
    '両取り': {
        'sourceUrl': 'https://www.shougi.jp/learn/tesuji/',
        'sourceTitle': '将棋研究',
    },
    '守り': {
        'sourceUrl': 'https://xn--pet04dr1n5x9a.com/tesuji/',
        'sourceTitle': '将棋講座.com',
    },
    '詰め': {
        'sourceUrl': '',
        'sourceTitle': '',
    },
    '捨て駒': {
        'sourceUrl': 'https://www.shougi.jp/learn/tesuji/',
        'sourceTitle': '将棋研究',
    },
}

def add_source_to_problem(match_text):
    """
    _TesujiProb(...) のマッチ部分に sourceUrl/sourceTitle を追加する
    """
    # category を抽出
    category_match = re.search(r"category:\s*'([^']+)'", match_text)
    if not category_match:
        return match_text

    category = category_match.group(1)

    # SOURCE_MAPPING に存在しないカテゴリの場合はスキップ
    if category not in SOURCE_MAPPING:
        return match_text

    # 既に sourceUrl が含まれている場合はスキップ
    if 'sourceUrl:' in match_text:
        return match_text

    # source 情報を取得
    source_info = SOURCE_MAPPING[category]
    source_url = source_info['sourceUrl']
    source_title = source_info['sourceTitle']

    # answer: ... の直後に sourceUrl/sourceTitle を挿入
    # answer: AMove(...) または answer: AMove(..., ...) の後を探す
    # 最後の )); の直前に挿入

    # パターン: )); で終わる部分を見つける
    if match_text.rstrip().endswith('));'):
        # 最後の , より前の部分を確認
        # answer の行を見つけて、その後に sourceUrl を追加

        # 最も安全な方法: 最後の )); の直前に改行 + sourceUrl + sourceTitle を挿入
        # インデント（2行分の余白）を保つ
        lines = match_text.rstrip('\n').rstrip().split('\n')

        # 最後の行の )); を見つけて、その前に新しい行を挿入
        if lines[-1].rstrip() == '));':
            # 最後の行の前に sourceUrl/sourceTitle を追加
            # インデントを合わせるため、answer 行と同じレベルに
            indent = '      '  # answer と同じインデント
            new_lines = lines[:-1] + [
                f"{indent}sourceUrl: '{source_url}',",
                f"{indent}sourceTitle: '{source_title}',",
                lines[-1]
            ]
            return '\n'.join(new_lines) + '\n'

    return match_text


def process_file(input_file, output_file):
    """
    ファイルを読み込んで sourceUrl/sourceTitle を追加し、出力する
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # _TesujiProb(...); のブロック全体をマッチさせる正規表現
    # 複数行モードで、list.add(_TesujiProb( から )); までをマッチ
    pattern = r'list\.add\(_TesujiProb\((.*?)\)\);'

    def replace_func(match):
        # マッチした全体（括弧内は含まない）
        full_text = 'list.add(_TesujiProb(' + match.group(1) + '));'
        return add_source_to_problem(full_text)

    # DOTALL フラグで . が改行にもマッチするように
    modified_content = re.sub(pattern, replace_func, content, flags=re.DOTALL)

    # 出力
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(modified_content)

    print(f"修正完了: {output_file}")


if __name__ == '__main__':
    input_file = r'[REDACTED_LOCAL_PATH]/lib\tesuji_screen.dart'
    output_file = r'[REDACTED_LOCAL_PATH]/lib\tesuji_screen.dart'

    process_file(input_file, output_file)
