package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	listenAddr      = ":8080"
	maxBodyBytes    = 1 << 20
	projectExt      = ".d2"
	defaultFileMode = 0o600
)

type appConfig struct {
	dataDir      string
	projectsDir  string
	defaultFile  string
	authEnabled  bool
	authUsername string
	authPassword string
}

type fileListResponse struct {
	Files []string `json:"files"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func getenvDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func mustLoadConfig() appConfig {
	cfg := appConfig{
		dataDir:      getenvDefault("D2_DATA_DIR", "/srv/d2"),
		defaultFile:  sanitizeFilename(getenvDefault("D2_DEFAULT_FILE", "main.d2")),
		authEnabled:  strings.EqualFold(getenvDefault("D2_AUTH_ENABLED", "true"), "true"),
		authUsername: getenvDefault("D2_AUTH_USERNAME", "admin"),
	}
	if cfg.defaultFile == "" {
		cfg.defaultFile = "main.d2"
	}
	cfg.projectsDir = filepath.Join(cfg.dataDir, "projects")

	if err := os.MkdirAll(cfg.projectsDir, 0o750); err != nil {
		log.Fatalf("create projects dir: %v", err)
	}

	if cfg.authEnabled {
		passwordPath := strings.TrimSpace(os.Getenv("D2_AUTH_PASSWORD_FILE"))
		if passwordPath == "" {
			log.Fatalf("D2_AUTH_PASSWORD_FILE is required when auth is enabled")
		}
		passwordBytes, err := os.ReadFile(passwordPath)
		if err != nil {
			log.Fatalf("read auth password file: %v", err)
		}
		cfg.authPassword = strings.TrimSpace(string(passwordBytes))
		if cfg.authPassword == "" {
			log.Fatalf("auth password file is empty")
		}
	}

	defaultPath := filepath.Join(cfg.projectsDir, cfg.defaultFile)
	if _, err := os.Stat(defaultPath); errors.Is(err, os.ErrNotExist) {
		starter := "direction: right\n\napp: D2 service\napp -> users: served via Traefik\n"
		if writeErr := os.WriteFile(defaultPath, []byte(starter), defaultFileMode); writeErr != nil {
			log.Fatalf("create default file: %v", writeErr)
		}
	}

	return cfg
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeErr(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}

func sanitizeFilename(name string) string {
	base := filepath.Base(strings.TrimSpace(name))
	if base == "." || base == "" {
		return ""
	}
	if strings.Contains(base, "..") || strings.ContainsAny(base, `/\\`) {
		return ""
	}
	if !strings.HasSuffix(base, projectExt) {
		base = base + projectExt
	}
	return base
}

func basicAuthRequired(cfg appConfig, next http.Handler) http.Handler {
	if !cfg.authEnabled {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}
		username, password, ok := r.BasicAuth()
		if !ok || username != cfg.authUsername || password != cfg.authPassword {
			w.Header().Set("WWW-Authenticate", `Basic realm="D2"`)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func renderWithD2(source []byte) ([]byte, error) {
	tmpDir, err := os.MkdirTemp("", "d2-render-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmpDir)

	inPath := filepath.Join(tmpDir, "input.d2")
	outPath := filepath.Join(tmpDir, "output.svg")

	if err := os.WriteFile(inPath, source, defaultFileMode); err != nil {
		return nil, err
	}

	cmd := exec.Command("d2", inPath, outPath)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		errText := strings.TrimSpace(stderr.String())
		if errText == "" {
			errText = err.Error()
		}
		return nil, fmt.Errorf("d2 render failed: %s", errText)
	}

	return os.ReadFile(outPath)
}

func listFiles(projectsDir string) ([]string, error) {
	entries, err := os.ReadDir(projectsDir)
	if err != nil {
		return nil, err
	}
	files := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(name, projectExt) {
			files = append(files, name)
		}
	}
	sort.Strings(files)
	return files, nil
}

func main() {
	cfg := mustLoadConfig()

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok\n"))
	})

	mux.HandleFunc("/api/files", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		files, err := listFiles(cfg.projectsDir)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, fileListResponse{Files: files})
	})

	mux.HandleFunc("/api/file", func(w http.ResponseWriter, r *http.Request) {
		name := sanitizeFilename(r.URL.Query().Get("name"))
		if name == "" {
			writeErr(w, http.StatusBadRequest, "invalid file name")
			return
		}
		path := filepath.Join(cfg.projectsDir, name)

		switch r.Method {
		case http.MethodGet:
			data, err := os.ReadFile(path)
			if errors.Is(err, os.ErrNotExist) {
				writeErr(w, http.StatusNotFound, "file not found")
				return
			}
			if err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			_, _ = w.Write(data)
		case http.MethodPut:
			body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
			if err != nil {
				writeErr(w, http.StatusRequestEntityTooLarge, "payload too large")
				return
			}
			if err := os.WriteFile(path, body, defaultFileMode); err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	})

	mux.HandleFunc("/api/render", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
		if err != nil {
			writeErr(w, http.StatusRequestEntityTooLarge, "payload too large")
			return
		}
		svg, err := renderWithD2(body)
		if err != nil {
			writeErr(w, http.StatusBadRequest, err.Error())
			return
		}
		w.Header().Set("Content-Type", "image/svg+xml")
		_, _ = w.Write(svg)
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(indexHTML))
	})

	server := &http.Server{
		Addr:              listenAddr,
		Handler:           basicAuthRequired(cfg, mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("d2-web listening on %s (data=%s auth=%t)", listenAddr, cfg.dataDir, cfg.authEnabled)
	if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("server failed: %v", err)
	}
}

const indexHTML = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>D2 Workspace</title>
    <style>
      :root {
        color-scheme: light;
        font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
      }
      body {
        margin: 0;
        background: #f6f7f9;
        color: #1a1b1f;
      }
      header {
        background: #1f2937;
        color: #f9fafb;
        padding: 12px 16px;
        display: flex;
        gap: 10px;
        align-items: center;
        flex-wrap: wrap;
      }
      main {
        display: grid;
        grid-template-columns: minmax(320px, 1fr) minmax(320px, 1fr);
        gap: 12px;
        padding: 12px;
        min-height: calc(100vh - 72px);
      }
      .panel {
        background: white;
        border: 1px solid #d1d5db;
        border-radius: 8px;
        overflow: hidden;
        display: flex;
        flex-direction: column;
      }
      .panel h2 {
        margin: 0;
        padding: 10px 12px;
        font-size: 14px;
        background: #f3f4f6;
        border-bottom: 1px solid #d1d5db;
      }
      #source {
        width: 100%;
        min-height: 420px;
        border: 0;
        resize: vertical;
        padding: 12px;
        font-family: "IBM Plex Mono", "Cascadia Code", monospace;
        font-size: 14px;
        line-height: 1.4;
        box-sizing: border-box;
      }
      #preview {
        width: 100%;
        min-height: 420px;
        border: 0;
      }
      select,
      button,
      input {
        border-radius: 6px;
        border: 1px solid #9ca3af;
        padding: 7px 10px;
        font-size: 14px;
      }
      button {
        background: #111827;
        color: #fff;
        border-color: #111827;
        cursor: pointer;
      }
      button.secondary {
        background: #fff;
        color: #111827;
      }
      #status {
        margin-left: auto;
        font-size: 12px;
        opacity: 0.9;
      }
      @media (max-width: 1000px) {
        main {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <header>
      <label for="fileSelect">Project</label>
      <select id="fileSelect"></select>
      <button class="secondary" id="newFile">New</button>
      <button id="save">Save</button>
      <button id="render">Render</button>
      <span id="status">ready</span>
    </header>
    <main>
      <section class="panel">
        <h2>Source (.d2)</h2>
        <textarea id="source" spellcheck="false"></textarea>
      </section>
      <section class="panel">
        <h2>Preview (SVG)</h2>
        <iframe id="preview" title="D2 preview"></iframe>
      </section>
    </main>

    <script>
      const fileSelect = document.getElementById("fileSelect");
      const source = document.getElementById("source");
      const statusEl = document.getElementById("status");
      const preview = document.getElementById("preview");

      function setStatus(text) {
        statusEl.textContent = text;
      }

      async function listFiles() {
        const res = await fetch("/api/files");
        if (!res.ok) throw new Error("failed to list files");
        const payload = await res.json();
        return payload.files || [];
      }

      function normalizeName(name) {
        let base = (name || "").trim().replace(/[\\/]+/g, "");
        if (!base) return "";
        if (!base.endsWith(".d2")) base += ".d2";
        return base;
      }

      async function refreshFileSelect(preferred) {
        const files = await listFiles();
        fileSelect.innerHTML = "";
        files.forEach((name) => {
          const option = document.createElement("option");
          option.value = name;
          option.textContent = name;
          fileSelect.appendChild(option);
        });
        if (files.length === 0) {
          fileSelect.disabled = true;
          source.value = "";
          return;
        }
        fileSelect.disabled = false;
        const selected = files.includes(preferred) ? preferred : files[0];
        fileSelect.value = selected;
        await loadFile(selected);
      }

      async function loadFile(name) {
        const res = await fetch("/api/file?name=" + encodeURIComponent(name));
        if (!res.ok) throw new Error("failed to load file");
        source.value = await res.text();
      }

      async function saveFile(name, content) {
        const res = await fetch("/api/file?name=" + encodeURIComponent(name), {
          method: "PUT",
          headers: { "Content-Type": "text/plain; charset=utf-8" },
          body: content,
        });
        if (!res.ok) {
          const payload = await res.json().catch(() => ({}));
          throw new Error(payload.error || "failed to save file");
        }
      }

      async function render(content) {
        const res = await fetch("/api/render", {
          method: "POST",
          headers: { "Content-Type": "text/plain; charset=utf-8" },
          body: content,
        });
        const payload = await res.text();
        if (!res.ok) {
          let parsed;
          try { parsed = JSON.parse(payload); } catch { parsed = null; }
          throw new Error((parsed && parsed.error) || payload || "render failed");
        }
        const doc = preview.contentDocument;
        doc.open();
        doc.write(payload);
        doc.close();
      }

      document.getElementById("newFile").addEventListener("click", async () => {
        const name = normalizeName(prompt("New file name", "diagram.d2"));
        if (!name) return;
        try {
          await saveFile(name, "");
          await refreshFileSelect(name);
          setStatus("created " + name);
        } catch (err) {
          setStatus(err.message);
        }
      });

      document.getElementById("save").addEventListener("click", async () => {
        const name = fileSelect.value;
        if (!name) return;
        try {
          await saveFile(name, source.value);
          setStatus("saved " + name);
        } catch (err) {
          setStatus(err.message);
        }
      });

      document.getElementById("render").addEventListener("click", async () => {
        try {
          setStatus("rendering...");
          await render(source.value);
          setStatus("rendered");
        } catch (err) {
          setStatus(err.message);
        }
      });

      fileSelect.addEventListener("change", async () => {
        try {
          await loadFile(fileSelect.value);
          setStatus("loaded " + fileSelect.value);
        } catch (err) {
          setStatus(err.message);
        }
      });

      (async () => {
        try {
          await refreshFileSelect("main.d2");
          if (fileSelect.value) {
            await render(source.value);
          }
          setStatus("ready");
        } catch (err) {
          setStatus(err.message);
        }
      })();
    </script>
  </body>
</html>`
