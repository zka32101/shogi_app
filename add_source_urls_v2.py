#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tesuji_screen.dart の 55問に sourceUrl/sourceTitle を一括追加するスクリプト（改良版）

行ベースの処理により、複雑な正規表現を避けて安定した変換を実現します。
"""

import re
from typing import Dict, List, Optional, Tuple

# 修正ルール: カテゴリ別の参照元情報
SOURCE_MAPPING: Dict[str, Dict[str, str]] = {
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

INDENT: str = '      '


def extract_block_category(block_text: str) -> Optional[str]:
    """ブロック内からカテゴリを抽出する。

    Args:
        block_text: 問題ブロック全体のテキスト

    Returns:
        抽出されたカテゴリ、またはNone
    """
    match = re.search(r"category:\s*'([^']+)'", block_text)
    return match.group(1) if match else None


def should_add_source(block_text: str, category: Optional[str]) -> bool:
    """参照元情報を追加すべきかを判定する。

    Args:
        block_text: 問題ブロックのテキスト
        category: カテゴリ名

    Returns:
        参照元情報を追加すべき場合 True
    """
    if category is None or category not in SOURCE_MAPPING:
        return False
    if 'sourceUrl:' in block_text:
        return False
    source_info = SOURCE_MAPPING[category]
    return source_info['sourceUrl'] != ''


def add_source_to_block_lines(block_lines: List[str], source_url: str, source_title: str) -> List[str]:
    """ブロック行に参照元情報を挿入する。

    Args:
        block_lines: ブロックの行リスト
        source_url: 参照元の URL
        source_title: 参照元のタイトル

    Returns:
        参照元情報が挿入された行リスト
    """
    result: List[str] = []
    for i, line in enumerate(block_lines):
        if i == len(block_lines) - 1 and '));' in line:
            result.append(f"{INDENT}sourceUrl: '{source_url}',\n")
            result.append(f"{INDENT}sourceTitle: '{source_title}',\n")
            result.append(line)
        else:
            result.append(line)
    return result


def extract_problem_block(lines: List[str], start_idx: int) -> Tuple[List[str], int]:
    """list.add(_TesujiProb(...)); ブロック全体を抽出する。

    Args:
        lines: 全ファイル行
        start_idx: ブロック開始インデックス

    Returns:
        (抽出されたブロック行, 次のインデックス)
    """
    block_lines: List[str] = [lines[start_idx]]
    i = start_idx + 1

    while i < len(lines):
        block_lines.append(lines[i])
        if '));' in lines[i]:
            return block_lines, i + 1
        i += 1

    return block_lines, i


def process_lines(lines: List[str]) -> List[str]:
    """全ファイル行を処理して、参照元情報を追加する。

    Args:
        lines: 入力ファイルの行リスト

    Returns:
        処理済みの行リスト
    """
    output_lines: List[str] = []
    i = 0

    while i < len(lines):
        if 'list.add(_TesujiProb(' in lines[i]:
            block_lines, next_idx = extract_problem_block(lines, i)
            block_text = ''.join(block_lines)
            category = extract_block_category(block_text)

            if should_add_source(block_text, category):
                source_info = SOURCE_MAPPING[category]
                block_lines = add_source_to_block_lines(
                    block_lines, source_info['sourceUrl'], source_info['sourceTitle']
                )

            output_lines.extend(block_lines)
            i = next_idx
        else:
            output_lines.append(lines[i])
            i += 1

    return output_lines


def process_file(input_file: str, output_file: str) -> None:
    """ファイルを読み込んで sourceUrl/sourceTitle を追加し、出力する。

    Args:
        input_file: 入力ファイルパス
        output_file: 出力ファイルパス
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    output_lines = process_lines(lines)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(output_lines)

    print(f"修正完了: {output_file}")


if __name__ == '__main__':
    input_file = r'G:\マイドライブ\apps\shogi_app\lib\tesuji_screen.dart'
    output_file = r'G:\マイドライブ\apps\shogi_app\lib\tesuji_screen.dart'

    process_file(input_file, output_file)
