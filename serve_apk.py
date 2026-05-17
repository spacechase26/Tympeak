#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 8889
APK_PATH = '/home/coder/Tympeak/build/app/outputs/flutter-apk/app-release.apk'
APK_NAME = 'Tympeak.apk'

class APKHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if not os.path.exists(APK_PATH):
            self.send_error(404, 'APK not found')
            return
        size = os.path.getsize(APK_PATH)
        self.send_response(200)
        self.send_header('Content-Type', 'application/vnd.android.package-archive')
        self.send_header('Content-Length', str(size))
        self.send_header('Content-Disposition', f'attachment; filename="{APK_NAME}"')
        self.end_headers()
        with open(APK_PATH, 'rb') as f:
            while chunk := f.read(65536):
                self.wfile.write(chunk)

    def log_message(self, fmt, *args):
        print(f'[apk] {self.address_string()} {fmt % args}')

with socketserver.TCPServer(('0.0.0.0', PORT), APKHandler) as httpd:
    print(f'Serving APK at http://0.0.0.0:{PORT}/')
    httpd.serve_forever()
