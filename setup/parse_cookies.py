import sys
import json

def parse_cookies(cookie_file):
    cookies = []
    with open(cookie_file, 'r') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            parts = line.strip().split('\t')
            if len(parts) >= 7:
                name = parts[5]
                value = parts[6]
                cookies.append(f"{name}={value}")
    return "; ".join(cookies)

if __name__ == "__main__":
    cookie_file = sys.argv[1]
    output_file = sys.argv[2]
    
    cookie_string = parse_cookies(cookie_file)
    
    headers = {
        "Cookie": cookie_string,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
    }
    
    with open(output_file, 'w') as f:
        json.dump(headers, f, indent=2)
    
    print(f"Generated {output_file}")
