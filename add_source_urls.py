#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tesuji_screen.dart の 55問に sourceUrl/sourceTitle を一括追加するスクリプト

このスクリプトは詰将棋問題の Dart コード内に、参照元の URL と タイトルを自動的に追加します。
"""

import re
from typing import Dict, Optional, Tuple

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


def extract_category(match_text: str) -> Optional[str]:
    """問題テキストからカテゴリを抽出する。

    Args:
        match_text: 問題ブロックのテキスト

    Returns:
        抽出されたカテゴリ名、またはNone
    """
    category_match = re.search(r"category:\s*'([^']+)'", match_text)
    return category_match.group(1) if category_match else None


def should_add_source(match_text: str, category: str) -> bool:
    """参照元情報を追加するべきかを判定する。

    Args:
        match_text: 問題ブロックのテキスト
        category: カテゴリ名

    Returns:
        参照元情報を追加すべき場合 True
    """
    if 'sourceUrl:' in match_text:
        return False
    if category not in SOURCE_MAPPING:
        return False
    source_info = SOURCE_MAPPING[category]
    return source_info['sourceUrl'] != ''


def build_source_lines(
    source_url: str, source_title: str, indent: str = '      '
) -> Tuple[str, str]:
    """参照元情報の行を構築する。

    Args:
        source_url: 参照元の URL
        source_title: 参照元のタイトル
        indent: インデント文字列

    Returns:
        sourceUrl と sourceTitle の行タプル
    """
    return (
        f"{indent}sourceUrl: '{source_url}',",
        f"{indent}sourceTitle: '{source_title}',",
    )


def insert_source_to_block(match_text: str, source_url: str, source_title: str) -> str:
    """問題ブロックに参照元情報を挿入する。

    Args:
        match_text: 問題ブロックのテキスト
        source_url: 参照元の URL
        source_title: 参照元のタイトル

    Returns:
        参照元情報が挿入されたテキスト
    """
    if not source_url or not match_text.rstrip().endswith('));'):
        return match_text

    lines = match_text.rstrip('\n').rstrip().split('\n')
    if len(lines) < 2 or lines[-1].rstrip() != '));':
        return match_text

    url_line, title_line = build_source_lines(source_url, source_title)
    new_lines = lines[:-1] + [url_line, title_line, lines[-1]]
    return '\n'.join(new_lines) + '\n'


def add_source_to_problem(match_text: str) -> str:
    """_TesujiProb(...) ブロックに参照元情報を追加する。

    Args:
        match_text: マッチした問題ブロックのテキスト

    Returns:
        参照元情報が追加されたテキスト
    """
    category = extract_category(match_text)
    if not category or not should_add_source(match_text, category):
        return match_text

    source_info = SOURCE_MAPPING[category]
    return insert_source_to_block(
        match_text, source_info['sourceUrl'], source_info['sourceTitle']
    )


def process_file(input_file: str, output_file: str) -> None:
    """ファイルを読み込んで sourceUrl/sourceTitle を追加し、出力する。

    Args:
        input_file: 入力ファイルパス
        output_file: 出力ファイルパス
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r'list\.add\(_TesujiProb\((.*?)\)\);'

    def replace_func(match: re.Match[str]) -> str:
        full_text = 'list.add(_TesujiProb(' + match.group(1) + '));'
        return add_source_to_problem(full_text)

    modified_content = re.sub(pattern, replace_func, content, flags=re.DOTALL)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(modified_content)

    print(f"修正完了: {output_file}")


if __name__ == '__main__':
    input_file = r'G:\マイドライブ\apps\shogi_app\lib\tesuji_screen.dart'
    output_file = r'G:\マイドライブ\apps\shogi_app\lib\tesuji_screen.dart'

    process_file(input_file, output_file)
