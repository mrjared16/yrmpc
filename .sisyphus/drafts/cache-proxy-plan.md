# Cache + Stream Proxy Architecture Plan

## Problem Statement

The EDL approach has a fundamental timing mismatch:
- EDL uses **TIME** offsets (`length=10`, `start=10`)
- But audio packets don't align to exact second boundaries
- Result: ~20ms gap or overlap at cache→stream transition

## Research Findings

### Option C (ffprobe actual duration) - FEASIBLE but IMPERFECT

| Method | Result | Time |
|--------|--------|------|
| `ffprobe format=duration` | 254s (WRONG - metadata) | 5ms |
| `ffprobe show_packets pts_time \| tail -1` | 12.134s (CORRECT) | 72ms |

**Problem**: Even with exact duration (12.134s), MPV's time-based seek on the stream may not land exactly at 12.134s due to packet boundaries.

### Option B (HTTP Proxy) - TRULY SEAMLESS

```
MPV ──GET──▶ http://127.0.0.1:PORT/audio/{video_id}
                        │
                        ▼
           ┌────────────────────────┐
           │    Local HTTP Proxy    │
           │                        │
           │  byte 0..N:    CACHE   │ ◀── From local file
           │  byte N+1..:   STREAM  │ ◀── Proxied from YouTube
           └────────────────────────┘
                        │
                        ▼
           MPV sees: ONE continuous bytestream
           ZERO gap/overlap (byte-perfect)
```

## Go PoC Code

```go
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
)

var (
	cacheFile string
	streamURL string
	port      int
)

func init() {
	flag.StringVar(&cacheFile, "cache", "", "Path to cached audio file")
	flag.StringVar(&streamURL, "stream", "", "YouTube stream URL")
	flag.IntVar(&port, "port", 9876, "Port to listen on")
}

func main() {
	flag.Parse()

	if cacheFile == "" || streamURL == "" {
		log.Fatal("Usage: go run main.go -cache /path/to/cache.webm -stream 'https://...'")
	}

	cacheInfo, _ := os.Stat(cacheFile)
	cacheSize := cacheInfo.Size()

	log.Printf("Cache: %s (%d bytes)", cacheFile, cacheSize)
	log.Printf("Listening on http://127.0.0.1:%d/audio", port)
	log.Printf("Test: mpv --no-video http://127.0.0.1:%d/audio", port)

	http.HandleFunc("/audio", func(w http.ResponseWriter, r *http.Request) {
		handleAudio(w, r, cacheSize)
	})

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), nil))
}

func handleAudio(w http.ResponseWriter, r *http.Request, cacheSize int64) {
	log.Printf("[%s] %s Range: %s", r.Method, r.URL.Path, r.Header.Get("Range"))

	rangeHeader := r.Header.Get("Range")
	
	if rangeHeader == "" {
		// No range - serve full stream (cache + origin)
		serveFullStream(w, cacheSize)
		return
	}

	start, end := parseRange(rangeHeader)
	
	if start < cacheSize {
		// Request starts within cache
		serveFromCache(w, start, end, cacheSize)
	} else {
		// Request beyond cache - proxy to origin
		serveFromStream(w, start, end)
	}
}

func serveFullStream(w http.ResponseWriter, cacheSize int64) {
	log.Printf("  Full stream: cache[0-%d] + origin[%d+]", cacheSize-1, cacheSize)

	w.Header().Set("Content-Type", "audio/webm")
	w.Header().Set("Accept-Ranges", "bytes")

	// Serve cache
	cache, _ := os.Open(cacheFile)
	defer cache.Close()
	cacheBytes, _ := io.Copy(w, cache)
	log.Printf("  Sent %d bytes from cache", cacheBytes)

	// Continue from origin
	req, _ := http.NewRequest("GET", streamURL, nil)
	req.Header.Set("Range", fmt.Sprintf("bytes=%d-", cacheSize))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("  Origin error: %v", err)
		return
	}
	defer resp.Body.Close()

	streamBytes, _ := io.Copy(w, resp.Body)
	log.Printf("  Sent %d bytes from origin", streamBytes)
}

func serveFromCache(w http.ResponseWriter, start, end, cacheSize int64) {
	cache, _ := os.Open(cacheFile)
	defer cache.Close()
	cache.Seek(start, 0)

	// How much from cache?
	cacheEnd := end
	if cacheEnd >= cacheSize || cacheEnd < 0 {
		cacheEnd = cacheSize - 1
	}
	
	cacheLen := cacheEnd - start + 1
	
	w.Header().Set("Content-Type", "audio/webm")
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/*", start, cacheEnd))
	w.WriteHeader(206)

	written, _ := io.CopyN(w, cache, cacheLen)
	log.Printf("  Cache: %d bytes [%d-%d]", written, start, cacheEnd)

	// Need more from origin?
	if end > cacheEnd && end > 0 {
		log.Printf("  Continuing from origin at byte %d", cacheSize)
		req, _ := http.NewRequest("GET", streamURL, nil)
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", cacheSize, end))

		resp, _ := http.DefaultClient.Do(req)
		defer resp.Body.Close()

		streamBytes, _ := io.Copy(w, resp.Body)
		log.Printf("  Origin: %d bytes", streamBytes)
	}
}

func serveFromStream(w http.ResponseWriter, start, end int64) {
	log.Printf("  Beyond cache, proxying origin [%d-%d]", start, end)

	req, _ := http.NewRequest("GET", streamURL, nil)
	if end > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", start, end))
	} else {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", start))
	}

	resp, _ := http.DefaultClient.Do(req)
	defer resp.Body.Close()

	for k, v := range resp.Header {
		w.Header()[k] = v
	}
	w.WriteHeader(resp.StatusCode)

	written, _ := io.Copy(w, resp.Body)
	log.Printf("  Proxied %d bytes", written)
}

func parseRange(header string) (start, end int64) {
	header = strings.TrimPrefix(header, "bytes=")
	parts := strings.Split(header, "-")
	start, _ = strconv.ParseInt(parts[0], 10, 64)
	if len(parts) > 1 && parts[1] != "" {
		end, _ = strconv.ParseInt(parts[1], 10, 64)
	} else {
		end = -1
	}
	return
}
```

## Test Commands

```bash
# 1. Get stream URL
STREAM_URL=$(ytx music hbl2Cuw75oE 2>&1 | grep '"url":' | head -1 | sed 's/.*"url": "\(.*\)".*/\1/')

# 2. Download cache (first 10s at 288kbps)
curl -r 0-360000 "$STREAM_URL" -o /tmp/test_cache.webm

# 3. Run proxy
cd poc-proxy && go run main.go -cache /tmp/test_cache.webm -stream "$STREAM_URL"

# 4. Test with MPV (in another terminal)
mpv --no-video http://127.0.0.1:9876/audio
```

## Integration into Daemon

Once PoC works, integrate into Rust daemon:

1. Add HTTP server to daemon (hyper or axum)
2. Route: `GET /audio/{video_id}` 
3. Lookup cache file and stream URL
4. Serve cache bytes then proxy origin
5. MPV connects to `http://127.0.0.1:{daemon_port}/audio/{video_id}`

## Bitrate Fix (Separate Issue)

Current: `default_bitrate_bps: 160_000` (wrong)
Should be: `288_000` (from ytx output)

Or better: pass bitrate from ytx extraction result.

## Queue Repeat Bug (Tracked in Beads)

Created bead: `yrmpc-XXX` - 1-item queue repeats after EOF despite RepeatMode::Off

Root cause hypothesis: After EOF→Stop→Idle, something sends Play command and `handle_play()` defaults to pos=0 when current_index=None.
