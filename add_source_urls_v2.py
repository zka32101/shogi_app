#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tesuji_screen.dart の 55問に sourceUrl/sourceTitle を一括追加するスクリプト（改良版）
"""

import re

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

def process_file(input_file, output_file):
    """
    ファイルを読み込んで sourceUrl/sourceTitle を追加する
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    output_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # list.add(_TesujiProb( を見つけたら、ブロック全体を処理
        if 'list.add(_TesujiProb(' in line:
            block_lines = [line]
            i += 1

            # )); に到達するまで読み込む
            while i < len(lines):
                block_lines.append(lines[i])
                if '));' in lines[i]:
                    break
                i += 1

            # ブロック内の category を抽出
            block_text = ''.join(block_lines)
            category_match = re.search(r"category:\s*'([^']+)'", block_text)

            if category_match:
                category = category_match.group(1)

                # sourceUrl がまだない場合のみ追加
                if 'sourceUrl:' not in block_text and category in SOURCE_MAPPING:
                    source_info = SOURCE_MAPPING[category]
                    source_url = source_info['sourceUrl']
                    source_title = source_info['sourceTitle']

                    # ブロック内の最後の )); の直前に sourceUrl/sourceTitle を挿入
                    new_block_lines = []
                    for j, bline in enumerate(block_lines):
                        if j == len(block_lines) - 1 and '));' in bline:
                            # 最後の行の直前に sourceUrl/sourceTitle を追加
                            # インデントは6スペース（answer と同じ）
                            new_block_lines.append(f"      sourceUrl: '{source_url}',\n")
                            new_block_lines.append(f"      sourceTitle: '{source_title}',\n")
                            new_block_lines.append(bline)
                        else:
                            new_block_lines.append(bline)

                    output_lines.extend(new_block_lines)
                else:
                    output_lines.extend(block_lines)
            else:
                output_lines.extend(block_lines)
        else:
            output_lines.append(line)

        i += 1

    # 出力
    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(output_lines)

    print(f"修正完了: {output_file}")


if __name__ == '__main__':
    input_file = r'[REDACTED_LOCAL_PATH]/lib\tesuji_screen.dart'
    output_file = r'[REDACTED_LOCAL_PATH]/lib\tesuji_screen.dart'

    process_file(input_file, output_file)
