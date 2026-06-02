#!/usr/bin/env python3
"""
serve.py — COOP/COEP ヘッダー付き開発用 HTTP サーバー

SharedArrayBuffer (WASM スレッド) を有効にするために
Cross-Origin-Opener-Policy と Cross-Origin-Embedder-Policy を追加する。

使い方:
    python serve.py                        # localhost:8788 で build/web を配信
    python serve.py --port 8080 --dir .    # カスタム設定
"""

import argparse
import http.server
import os
import socketserver


class COIHandler(http.server.SimpleHTTPRequestHandler):
    """Cross-Origin Isolation ヘッダーを付けて静的ファイルを配信するハンドラ。"""

    def end_headers(self):
        # credentialless = CORS ヘッダーがある外部リソースを許可（CDN から WASM を取得可能）
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()

    def log_message(self, fmt, *args):
        # 簡略ログ
        print(f'  {args[0]} {args[1]}')


def main():
    parser = argparse.ArgumentParser(description='COI 対応 HTTP サーバー')
    parser.add_argument('--port', type=int, default=8788, help='ポート番号 (default: 8788)')
    parser.add_argument('--dir',  default='build/web',   help='配信ディレクトリ (default: build/web)')
    args = parser.parse_args()

    serve_dir = os.path.abspath(args.dir)
    if not os.path.isdir(serve_dir):
        print(f'[ERROR] ディレクトリが存在しません: {serve_dir}')
        print('先に flutter build web を実行してください。')
        raise SystemExit(1)

    os.chdir(serve_dir)

    with socketserver.TCPServer(('', args.port), COIHandler) as httpd:
        httpd.allow_reuse_address = True
        print(f'Serving: {serve_dir}')
        print(f'URL    : http://localhost:{args.port}')
        print(f'Headers: COOP=same-origin  COEP=credentialless')
        print('Ctrl+C で停止\n')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n停止しました。')


if __name__ == '__main__':
    main()
