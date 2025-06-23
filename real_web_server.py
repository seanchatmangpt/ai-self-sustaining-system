#!/usr/bin/env python3
import http.server
import socketserver
import json
import time
import os
from urllib.parse import parse_qs, urlparse

class RealOperationsHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.ops_log = "/Users/sac/dev/ai-self-sustaining-system/real_web_operations.log"
        super().__init__(*args, **kwargs)
    
    def log_operation(self, operation, details=""):
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime())
        with open(self.ops_log, "a") as f:
            f.write(f"{timestamp} {operation} {details}\n")
    
    def do_GET(self):
        self.log_operation("GET", self.path)
        
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<h1>Real Operations Server</h1><p>Actually serving requests!</p>")
        
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health_data = {
                "status": "healthy",
                "timestamp": time.time(),
                "operations_logged": self.count_operations()
            }
            self.wfile.write(json.dumps(health_data).encode())
        
        elif self.path == '/work':
            # Simulate doing actual work
            self.do_actual_work()
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"Work completed")
        
        else:
            super().do_GET()
    
    def do_actual_work(self):
        # Actually create a file with timestamp
        work_file = f"/Users/sac/dev/ai-self-sustaining-system/work_output_{int(time.time())}.txt"
        with open(work_file, "w") as f:
            f.write(f"Work completed at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        self.log_operation("WORK", f"created {work_file}")
    
    def count_operations(self):
        try:
            with open(self.ops_log, "r") as f:
                return len(f.readlines())
        except:
            return 0

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), RealOperationsHandler) as httpd:
        print(f"Real operations server running on port {PORT}")
        httpd.serve_forever()
