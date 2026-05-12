#!/usr/bin/env python3
"""
FIN1 Server Control Panel
Ein einfaches GUI zum Verwalten der Docker-Container
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import subprocess
import threading
import json
import os
import sys

class FIN1ControlPanel:
    def __init__(self, root):
        self.root = root
        self.root.title("FIN1 Server Control Panel")
        self.root.geometry("900x700")
        self.root.resizable(True, True)

        # Docker Compose Datei
        base_dir = os.path.dirname(__file__)
        # Best effort: prefer the active stack if present.
        # This avoids false "not 100% healthy" warnings when the panel points to a compose file
        # that is not the one currently running.
        preferred = ["docker-compose.yml", "docker-compose.production.yml"]
        self.compose_file = next(
            (os.path.join(base_dir, f) for f in preferred if os.path.exists(os.path.join(base_dir, f))),
            os.path.join(base_dir, "docker-compose.production.yml"),
        )

        # Services
        self.services = [
            {"name": "parse-server", "display": "Parse Server", "port": "1337"},
            {"name": "mongodb", "display": "MongoDB", "port": "27017"},
            {"name": "postgres", "display": "PostgreSQL", "port": "5432"},
            {"name": "redis", "display": "Redis", "port": "6379"},
            {"name": "minio", "display": "MinIO", "port": "9000"},
            {"name": "nginx", "display": "Nginx", "port": "80"},
            {"name": "market-data", "display": "Market Data", "port": "8080"},
            {"name": "notification-service", "display": "Notification Service", "port": "8081"},
            {"name": "analytics-service", "display": "Analytics Service", "port": "8082"},
        ]

        self.setup_ui()
        self.update_status()

        # Auto-Update alle 5 Sekunden
        self.auto_update()

    def setup_ui(self):
        # Haupt-Frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Titel
        title = ttk.Label(main_frame, text="FIN1 Server Control Panel",
                         font=("Arial", 16, "bold"))
        title.grid(row=0, column=0, columnspan=4, pady=(0, 20))

        # PanedWindow mit dragbarer Trennlinie zwischen "oben" und "Logs".
        # Dadurch kann man die Logs deutlich höher ziehen, ohne die gesamte
        # Applikation zu vergrößern.
        paned = ttk.Panedwindow(main_frame, orient="vertical")
        paned.grid(row=1, column=0, columnspan=4, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        top_frame = ttk.Frame(paned)
        bottom_frame = ttk.Frame(paned)
        # "Unten" (Logs) initial etwas größer, damit der Nutzwert direkt höher ist.
        paned.add(top_frame, weight=2)
        paned.add(bottom_frame, weight=3)

        # Service-Status Frame
        status_frame = ttk.LabelFrame(top_frame, text="Service Status", padding="10")
        status_frame.grid(row=0, column=0, columnspan=4, sticky=(tk.W, tk.E), pady=10)

        # Treeview für Services
        columns = ("Service", "Status", "Port", "Health")
        self.tree = ttk.Treeview(status_frame, columns=columns, show="headings", height=8)

        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=150)

        self.tree.grid(row=0, column=0, columnspan=4, sticky=(tk.W, tk.E))

        # Scrollbar
        scrollbar = ttk.Scrollbar(status_frame, orient="vertical", command=self.tree.yview)
        scrollbar.grid(row=0, column=4, sticky=(tk.N, tk.S))
        self.tree.configure(yscrollcommand=scrollbar.set)

        # Buttons Frame
        button_frame = ttk.Frame(top_frame, padding="10")
        button_frame.grid(row=1, column=0, columnspan=4, pady=10)

        ttk.Button(button_frame, text="🔄 Status aktualisieren",
                  command=self.update_status).grid(row=0, column=0, padx=5)
        ttk.Button(button_frame, text="▶️ Alle starten",
                  command=self.start_all).grid(row=0, column=1, padx=5)
        ttk.Button(button_frame, text="⏹️ Alle stoppen",
                  command=self.stop_all).grid(row=0, column=2, padx=5)
        ttk.Button(button_frame, text="🔄 Alle neu starten",
                  command=self.restart_all).grid(row=0, column=3, padx=5)
        ttk.Button(button_frame, text="📋 Logs anzeigen",
                  command=self.show_logs).grid(row=0, column=4, padx=5)

        # Smoke-Check (zeigt Ergebnisse im Log-Bereich)
        self.smoke_check_btn = ttk.Button(
            button_frame,
            text="🧪 Smoke-Check",
            command=self.run_smoke_check,
        )
        self.smoke_check_btn.grid(row=1, column=0, columnspan=2, padx=5, pady=(10, 0))

        # Log-Fenster Höhe anpassbar machen (damit weniger Scrollen nötig ist)
        self.log_height_var = tk.IntVar(value=20)
        ttk.Label(button_frame, text="Log-Höhe").grid(row=1, column=2, padx=5, pady=(10, 0))
        ttk.Spinbox(
            button_frame,
            from_=5,
            to=80,
            increment=1,
            textvariable=self.log_height_var,
            width=6,
            command=self.apply_log_height,
        ).grid(row=1, column=3, padx=5, pady=(10, 0), sticky=(tk.W))
        ttk.Button(
            button_frame,
            text="Übernehmen",
            command=self.apply_log_height,
        ).grid(row=1, column=4, padx=5, pady=(10, 0), sticky=(tk.W))

        # Service-spezifische Buttons
        service_frame = ttk.LabelFrame(top_frame, text="Service-Aktionen", padding="10")
        service_frame.grid(row=2, column=0, columnspan=4, sticky=(tk.W, tk.E), pady=10)

        ttk.Button(service_frame, text="▶️ Starten",
                  command=self.start_selected).grid(row=0, column=0, padx=5)
        ttk.Button(service_frame, text="⏹️ Stoppen",
                  command=self.stop_selected).grid(row=0, column=1, padx=5)
        ttk.Button(service_frame, text="🔄 Neu starten",
                  command=self.restart_selected).grid(row=0, column=2, padx=5)
        ttk.Button(service_frame, text="📋 Logs",
                  command=self.show_selected_logs).grid(row=0, column=3, padx=5)

        # Logs Frame
        logs_frame = ttk.LabelFrame(bottom_frame, text="Logs", padding="10")
        logs_frame.grid(row=0, column=0, columnspan=4, sticky=(tk.W, tk.E, tk.N, tk.S), pady=10)

        self.log_text = scrolledtext.ScrolledText(
            logs_frame,
            height=self.log_height_var.get(),
            width=80,
        )
        self.log_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Grid weights für Resizing
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(1, weight=1)
        top_frame.columnconfigure(0, weight=1)
        bottom_frame.columnconfigure(0, weight=1)
        bottom_frame.rowconfigure(0, weight=1)
        logs_frame.columnconfigure(0, weight=1)
        logs_frame.rowconfigure(0, weight=1)

    def apply_log_height(self):
        """Setzt die sichtbare Zeilenanzahl des Log-Fensters."""
        try:
            val = int(self.log_height_var.get())
            if val < 1:
                val = 1
            self.log_text.configure(height=val)
        except Exception:
            pass

    def run_smoke_check(self):
        """Startet den Server-Smoke-Check im Hintergrund."""
        if getattr(self, "smoke_check_running", False):
            return
        self.smoke_check_running = True
        try:
            self.smoke_check_btn.configure(state="disabled")
        except Exception:
            pass

        self.root.after(0, lambda: self.log("🧪 Starte Smoke-Check..."))
        threading.Thread(target=self._smoke_check_thread, daemon=True).start()

    def _smoke_check_thread(self):
        script_path = os.path.join(os.path.dirname(__file__), "scripts", "fin1-smoke-check.sh")
        try:
            result = subprocess.run(
                [script_path],
                capture_output=True,
                text=True,
                timeout=900,
            )

            # stdout/stderr zeilenweise anzeigen (damit das UI mit scrollen kann)
            if result.stdout:
                for line in result.stdout.splitlines():
                    self.root.after(0, lambda l=line: self.log(l))
            if result.stderr:
                for line in result.stderr.splitlines():
                    self.root.after(0, lambda l=line: self.log(l))

            if result.returncode == 0:
                self.root.after(0, lambda: self.log("✅ Smoke-Check PASS"))
            else:
                self.root.after(
                    0,
                    lambda: messagebox.showerror(
                        "Smoke-Check fehlgeschlagen",
                        f"Smoke-Check ist fehlgeschlagen (exit code {result.returncode}).",
                    ),
                )
        except Exception as e:
            self.root.after(0, lambda: self.log(f"❌ Smoke-Check Fehler: {e}"))
        finally:
            def _restore():
                self.smoke_check_running = False
                try:
                    self.smoke_check_btn.configure(state="normal")
                except Exception:
                    pass

            self.root.after(0, _restore)

    def run_command(self, command, background=False):
        """Führt einen Docker Compose Befehl aus"""
        try:
            cmd = ["docker", "compose", "-f", self.compose_file] + command
            if background:
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                         stderr=subprocess.PIPE, text=True)
                return process
            else:
                # Erhöhter Timeout für Start-Befehle (besonders nach Neustart)
                timeout = 300 if "up" in command else 120
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
                return result
        except subprocess.TimeoutExpired:
            self.log("⚠️ Befehl hat zu lange gedauert (Timeout)")
            return None
        except Exception as e:
            self.log(f"❌ Fehler: {str(e)}")
            return None

    def get_container_status(self):
        """Holt den Status aller Container"""
        result = self.run_command(["ps", "--format", "json"])
        if result and result.returncode == 0:
            containers = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    try:
                        container = json.loads(line)
                        containers.append(container)
                    except:
                        pass
            return containers
        return []

    def update_status(self):
        """Aktualisiert die Service-Status-Anzeige"""
        # Tree leeren
        for item in self.tree.get_children():
            self.tree.delete(item)

        containers = self.get_container_status()
        container_map = {c.get('Name', ''): c for c in containers}

        for service in self.services:
            container_name = f"fin1-{service['name']}"
            container = container_map.get(container_name, {})

            status = container.get('State', 'Nicht gestartet')
            health = container.get('Health', 'N/A')

            # Status-Icon
            if status == 'running':
                status_icon = "🟢"
                if health == 'healthy':
                    health_icon = "✅"
                elif health == 'unhealthy':
                    health_icon = "⚠️"
                elif health in ('starting', 'none', '', None):
                    # Healthcheck not available / still starting -> do not classify as broken.
                    health_icon = "🟡"
                else:
                    health_icon = "🟡"
            elif status == 'exited':
                status_icon = "🔴"
                health_icon = "❌"
            else:
                status_icon = "⚪"
                health_icon = "—"

            self.tree.insert("", "end", values=(
                service['display'],
                f"{status_icon} {status}",
                service['port'],
                health_icon
            ))

    def start_all(self):
        """Startet alle Services"""
        self.log("▶️ Starte alle Services...")
        threading.Thread(target=self._start_all_thread, daemon=True).start()

    def _start_all_thread(self):
        """Startet alle Services explizit und prüft den Status"""
        self.log("⏳ Starte alle Services...")

        # Hole alle definierten Services
        config_result = self.run_command(["config", "--services"])
        if not config_result or config_result.returncode != 0:
            self.log("❌ Konnte Services-Liste nicht abrufen")
            return

        all_services = [s.strip() for s in config_result.stdout.strip().split('\n') if s.strip()]
        self.log(f"📋 Gefundene Services: {', '.join(all_services)}")

        # Starte alle Services explizit (auch die, die bereits laufen)
        self.log("⏳ Starte Services ohne Build...")
        result = self.run_command(["up", "-d", "--remove-orphans"] + all_services)

        # Wenn ohne Build fehlgeschlagen, versuche mit Build
        if not result or result.returncode != 0:
            self.log("⏳ Start ohne Build fehlgeschlagen, versuche mit Build...")
            result = self.run_command(["up", "-d", "--build", "--remove-orphans"] + all_services)

        # Prüfe, ob alle Services wirklich gestartet wurden
        self.root.after(2000, self._verify_all_started)

        if result and result.returncode == 0:
            self.log("✅ Start-Befehl erfolgreich ausgeführt")
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"⚠️ Warnung beim Starten: {error[:200]}")
            else:
                self.log("⚠️ Warnung: Befehl konnte nicht vollständig ausgeführt werden")

    def _verify_all_started(self):
        """Prüft, ob alle Services wirklich gestartet wurden"""
        containers = self.get_container_status()
        container_map = {c.get('Name', ''): c for c in containers}

        started = []
        not_started = []
        unhealthy = []

        for service in self.services:
            container_name = f"fin1-{service['name']}"
            container = container_map.get(container_name, {})
            status = container.get('State', 'Nicht gestartet')
            health = container.get('Health', '')

            if status == 'running':
                if health == 'healthy':
                    started.append(service['display'])
                elif health == 'unhealthy':
                    unhealthy.append(service['display'])
                else:
                    started.append(service['display'])  # Läuft, aber noch kein Healthcheck
            else:
                not_started.append(service['display'])

        # Logge Status
        total_expected = len(self.services)
        total_running = len(started) + len(unhealthy)

        if started:
            self.log(f"✅ Gestartet ({len(started)}/{total_expected}): {', '.join(started)}")
        if unhealthy:
            self.log(f"⚠️ Unhealthy ({len(unhealthy)}): {', '.join(unhealthy)}")
            self.log("💡 Tipp: Unhealthy Services können abhängige Services blockieren")
        if not_started:
            self.log(f"❌ Nicht gestartet ({len(not_started)}/{total_expected}): {', '.join(not_started)}")
            error_msg = f"Nicht alle Services gestartet ({total_running}/{total_expected})\n\n"
            if unhealthy:
                error_msg += f"⚠️ Unhealthy Services ({len(unhealthy)}):\n" + "\n".join(unhealthy) + "\n\n"
            if not_started:
                error_msg += f"❌ Nicht gestartet ({len(not_started)}):\n" + "\n".join(not_started) + "\n\n"
            error_msg += "Bitte prüfen Sie die Logs für Details."
            self.root.after(0, lambda: messagebox.showwarning("Nicht alle Services gestartet", error_msg))
        elif total_running == total_expected:
            self.log(f"✅ Alle Services gestartet ({total_running}/{total_expected})")

        self.update_status()

    def stop_all(self):
        """Stoppt alle Services"""
        if messagebox.askyesno("Bestätigung", "Möchten Sie wirklich alle Services stoppen?"):
            self.log("⏹️ Stoppe alle Services...")
            threading.Thread(target=self._stop_all_thread, daemon=True).start()

    def _stop_all_thread(self):
        result = self.run_command(["stop"])
        if result and result.returncode == 0:
            self.log("✅ Alle Services gestoppt")
            self.root.after(0, self.update_status)
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"❌ Fehler beim Stoppen: {error}")
                self.root.after(0, lambda: messagebox.showerror("Fehler", f"Fehler beim Stoppen:\n{error}"))
            else:
                error_msg = "Befehl konnte nicht ausgeführt werden"
                self.log(f"❌ Fehler: {error_msg}")
                self.root.after(0, lambda: messagebox.showerror("Fehler", error_msg))

    def restart_all(self):
        """Startet alle Services neu"""
        if messagebox.askyesno("Bestätigung", "Möchten Sie wirklich alle Services neu starten?"):
            self.log("🔄 Starte alle Services neu...")
            threading.Thread(target=self._restart_all_thread, daemon=True).start()

    def _restart_all_thread(self):
        result = self.run_command(["restart"])
        if result and result.returncode == 0:
            self.log("✅ Alle Services neu gestartet")
            self.root.after(0, self.update_status)
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"❌ Fehler beim Neustarten: {error}")
                self.root.after(0, lambda: messagebox.showerror("Fehler", f"Fehler beim Neustarten:\n{error}"))
            else:
                error_msg = "Befehl konnte nicht ausgeführt werden"
                self.log(f"❌ Fehler: {error_msg}")
                self.root.after(0, lambda: messagebox.showerror("Fehler", error_msg))

    def start_selected(self):
        """Startet den ausgewählten Service"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("Warnung", "Bitte wählen Sie einen Service aus")
            return

        item = self.tree.item(selection[0])
        service_name = item['values'][0]
        service = next((s for s in self.services if s['display'] == service_name), None)

        if service:
            self.log(f"▶️ Starte {service['display']}...")
            threading.Thread(target=self._start_service_thread,
                           args=(service['name'],), daemon=True).start()

    def _start_service_thread(self, service_name):
        result = self.run_command(["up", "-d", service_name])
        if result and result.returncode == 0:
            self.log(f"✅ {service_name} gestartet")
            self.root.after(0, self.update_status)
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"❌ Fehler beim Starten von {service_name}: {error}")
            else:
                self.log(f"❌ Fehler: Befehl konnte nicht ausgeführt werden")

    def stop_selected(self):
        """Stoppt den ausgewählten Service"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("Warnung", "Bitte wählen Sie einen Service aus")
            return

        item = self.tree.item(selection[0])
        service_name = item['values'][0]
        service = next((s for s in self.services if s['display'] == service_name), None)

        if service:
            self.log(f"⏹️ Stoppe {service['display']}...")
            threading.Thread(target=self._stop_service_thread,
                           args=(service['name'],), daemon=True).start()

    def _stop_service_thread(self, service_name):
        result = self.run_command(["stop", service_name])
        if result and result.returncode == 0:
            self.log(f"✅ {service_name} gestoppt")
            self.root.after(0, self.update_status)
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"❌ Fehler: {error}")
            else:
                self.log(f"❌ Fehler: Befehl konnte nicht ausgeführt werden")

    def restart_selected(self):
        """Startet den ausgewählten Service neu"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("Warnung", "Bitte wählen Sie einen Service aus")
            return

        item = self.tree.item(selection[0])
        service_name = item['values'][0]
        service = next((s for s in self.services if s['display'] == service_name), None)

        if service:
            self.log(f"🔄 Starte {service['display']} neu...")
            threading.Thread(target=self._restart_service_thread,
                           args=(service['name'],), daemon=True).start()

    def _restart_service_thread(self, service_name):
        result = self.run_command(["restart", service_name])
        if result and result.returncode == 0:
            self.log(f"✅ {service_name} neu gestartet")
            self.root.after(0, self.update_status)
        else:
            if result:
                error = result.stderr if result.stderr else result.stdout if result.stdout else "Unbekannter Fehler"
                self.log(f"❌ Fehler: {error}")
            else:
                self.log(f"❌ Fehler: Befehl konnte nicht ausgeführt werden")

    def show_logs(self):
        """Zeigt Logs aller Services"""
        log_window = tk.Toplevel(self.root)
        log_window.title("FIN1 Server Logs")
        log_window.geometry("800x600")

        log_text = scrolledtext.ScrolledText(log_window, wrap=tk.WORD)
        log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        def update_logs():
            result = self.run_command(["logs", "--tail", "100"])
            if result and result.returncode == 0:
                log_text.delete(1.0, tk.END)
                log_text.insert(1.0, result.stdout)
                log_text.see(tk.END)

        update_logs()

        refresh_btn = ttk.Button(log_window, text="🔄 Aktualisieren", command=update_logs)
        refresh_btn.pack(pady=5)

    def show_selected_logs(self):
        """Zeigt Logs des ausgewählten Services"""
        selection = self.tree.selection()
        if not selection:
            messagebox.showwarning("Warnung", "Bitte wählen Sie einen Service aus")
            return

        item = self.tree.item(selection[0])
        service_name = item['values'][0]
        service = next((s for s in self.services if s['display'] == service_name), None)

        if service:
            log_window = tk.Toplevel(self.root)
            log_window.title(f"Logs: {service['display']}")
            log_window.geometry("800x600")

            log_text = scrolledtext.ScrolledText(log_window, wrap=tk.WORD)
            log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

            def update_logs():
                result = self.run_command(["logs", "--tail", "200", service['name']])
                if result and result.returncode == 0:
                    log_text.delete(1.0, tk.END)
                    log_text.insert(1.0, result.stdout)
                    log_text.see(tk.END)

            update_logs()

            refresh_btn = ttk.Button(log_window, text="🔄 Aktualisieren", command=update_logs)
            refresh_btn.pack(pady=5)

            # Auto-Refresh alle 2 Sekunden
            def auto_refresh():
                update_logs()
                log_window.after(2000, auto_refresh)

            auto_refresh()

    def log(self, message):
        """Fügt eine Nachricht zum Log-Bereich hinzu"""
        self.log_text.insert(tk.END, f"{message}\n")
        self.log_text.see(tk.END)

    def auto_update(self):
        """Aktualisiert den Status automatisch"""
        self.update_status()
        self.root.after(5000, self.auto_update)


def main():
    # Prüfe ob tkinter verfügbar ist
    try:
        root = tk.Tk()
    except tk.TclError:
        print("❌ Fehler: tkinter ist nicht installiert.")
        print("Installieren Sie es mit: sudo apt-get install python3-tk")
        sys.exit(1)

    # Prüfe ob Docker verfügbar ist
    try:
        subprocess.run(["docker", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        messagebox.showerror("Fehler",
                           "Docker ist nicht installiert oder nicht verfügbar.\n"
                           "Bitte installieren Sie Docker zuerst.")
        sys.exit(1)

    # Prüfe ob docker-compose verfügbar ist
    try:
        subprocess.run(["docker", "compose", "version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        messagebox.showerror("Fehler",
                           "Docker Compose ist nicht verfügbar.\n"
                           "Bitte installieren Sie Docker Compose zuerst.")
        sys.exit(1)

    app = FIN1ControlPanel(root)
    root.mainloop()


if __name__ == "__main__":
    main()
