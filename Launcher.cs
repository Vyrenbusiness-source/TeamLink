using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class Launcher
{
    static Process _nodeProcess;

    [STAThread]
    static void Main()
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string serverDir = Path.Combine(root, "sync-server");
        string serverScript = Path.Combine(serverDir, "src", "index.js");
        string flutterExe = Path.Combine(root, "desktop-client", "build", "windows", "x64", "runner", "Release", "desktop_client.exe");
        string nodeModules = Path.Combine(serverDir, "node_modules");

        string mode = ReadMode(); // "host" | "joiner" | null (first run)

        // Joiner: skip the server entirely, just launch the Flutter app.
        if (mode == "joiner")
        {
            LaunchFlutter(flutterExe);
            return;
        }

        // Host mode (or first run): we need Node.js and the server.
        string node = FindNode(root);
        if (node == null)
        {
            MessageBox.Show(
                "Node.js wurde nicht gefunden.\n\n" +
                "Erwartet: portable Node unter '\\runtime\\node\\node.exe' " +
                "neben dieser EXE, oder System-Node im PATH.\n\n" +
                "Download: https://nodejs.org/de/download/",
                "TeamLink – Fehler",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        // Auto-run npm install if dependencies are missing.
        if (!Directory.Exists(nodeModules))
        {
            string npmCli = FindNpmCli(node, root);
            if (npmCli == null)
            {
                MessageBox.Show(
                    "npm-cli.js wurde nicht gefunden.\n\n" +
                    "Bitte einmalig manuell ausführen:\n" +
                    "  cd sync-server\n" +
                    "  npm install",
                    "TeamLink – Setup",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }
            if (!RunNpmInstall(node, npmCli, serverDir))
            {
                MessageBox.Show(
                    "npm install ist fehlgeschlagen. Prüfe deine Internetverbindung.",
                    "TeamLink – Setup fehlgeschlagen",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }
        }

        // Make cloudflared discoverable for the server process.
        string cloudflared = Path.Combine(root, "runtime", "cloudflared", "cloudflared.exe");
        var envCloudflared = File.Exists(cloudflared) ? cloudflared : null;

        var errorBuffer = new System.Text.StringBuilder();
        _nodeProcess = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = node,
                Arguments = "\"" + serverScript + "\"",
                WorkingDirectory = serverDir,
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            },
            EnableRaisingEvents = true,
        };
        if (envCloudflared != null)
        {
            _nodeProcess.StartInfo.EnvironmentVariables["CLOUDFLARED_BIN"] = envCloudflared;
        }
        _nodeProcess.ErrorDataReceived += (s, e) => { if (e.Data != null) errorBuffer.AppendLine(e.Data); };
        _nodeProcess.Exited += (s, e) =>
        {
            string err = errorBuffer.ToString();
            if (!string.IsNullOrWhiteSpace(err))
                MessageBox.Show("Backend-Fehler:\n\n" + err, "TeamLink – Server", MessageBoxButtons.OK, MessageBoxIcon.Error);
        };
        _nodeProcess.Start();
        _nodeProcess.BeginOutputReadLine();
        _nodeProcess.BeginErrorReadLine();

        AppDomain.CurrentDomain.ProcessExit += (s, e) => KillNode();

        LaunchFlutter(flutterExe);
        KillNode();
    }

    static void LaunchFlutter(string flutterExe)
    {
        if (!File.Exists(flutterExe))
        {
            MessageBox.Show(
                "Das Flutter-Frontend wurde noch nicht gebaut.\n\n" +
                "Bitte einmalig in einer PowerShell ausführen:\n\n" +
                "  cd desktop-client\n" +
                "  flutter build windows --release",
                "TeamLink – Frontend fehlt",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return;
        }
        var flutter = Process.Start(new ProcessStartInfo
        {
            FileName = flutterExe,
            WorkingDirectory = Path.GetDirectoryName(flutterExe),
            UseShellExecute = false,
        });
        if (flutter != null) flutter.WaitForExit();
    }

    static string ReadMode()
    {
        try
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string path = Path.Combine(appData, "TeamLink", "mode.txt");
            if (!File.Exists(path)) return null;
            return File.ReadAllText(path).Trim();
        }
        catch
        {
            return null;
        }
    }

    static void KillNode()
    {
        try { if (_nodeProcess != null && !_nodeProcess.HasExited) _nodeProcess.Kill(); }
        catch { }
    }

    static string FindNode(string root)
    {
        // Prefer bundled portable Node.
        string bundled = Path.Combine(root, "runtime", "node", "node.exe");
        if (File.Exists(bundled)) return bundled;

        try
        {
            var psi = new ProcessStartInfo("where.exe", "node.exe")
            {
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
            };
            var p = Process.Start(psi);
            string line = p.StandardOutput.ReadLine();
            p.WaitForExit();
            if (!string.IsNullOrWhiteSpace(line) && File.Exists(line.Trim()))
                return line.Trim();
        }
        catch { }
        return null;
    }

    static string FindNpmCli(string nodeExe, string root)
    {
        // For bundled portable Node, npm-cli.js lives in <node>/node_modules/npm/bin/npm-cli.js.
        string nodeDir = Path.GetDirectoryName(nodeExe);
        string candidate = Path.Combine(nodeDir, "node_modules", "npm", "bin", "npm-cli.js");
        if (File.Exists(candidate)) return candidate;

        // Fall back: search a few common system locations.
        string program = Environment.GetEnvironmentVariable("ProgramFiles");
        if (!string.IsNullOrEmpty(program))
        {
            string sys = Path.Combine(program, "nodejs", "node_modules", "npm", "bin", "npm-cli.js");
            if (File.Exists(sys)) return sys;
        }
        return null;
    }

    static bool RunNpmInstall(string nodeExe, string npmCli, string serverDir)
    {
        try
        {
            using (var setupForm = new SetupProgressForm("Abhängigkeiten installieren – einen Moment …"))
            {
                setupForm.Show();
                Application.DoEvents();

                var psi = new ProcessStartInfo
                {
                    FileName = nodeExe,
                    Arguments = "\"" + npmCli + "\" install --omit=dev",
                    WorkingDirectory = serverDir,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                };
                var p = Process.Start(psi);
                p.OutputDataReceived += (s, e) => { /* discard */ };
                p.ErrorDataReceived += (s, e) => { /* discard */ };
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                while (!p.HasExited)
                {
                    Application.DoEvents();
                    System.Threading.Thread.Sleep(100);
                }
                return p.ExitCode == 0;
            }
        }
        catch
        {
            return false;
        }
    }
}

class SetupProgressForm : Form
{
    public SetupProgressForm(string message)
    {
        Text = "TeamLink – Setup";
        Width = 420;
        Height = 140;
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = false;
        MaximizeBox = false;
        ControlBox = false;
        Controls.Add(new Label
        {
            Text = message,
            Dock = DockStyle.Top,
            TextAlign = System.Drawing.ContentAlignment.MiddleCenter,
            Height = 60,
            Font = new System.Drawing.Font("Segoe UI", 10),
        });
        var bar = new ProgressBar
        {
            Style = ProgressBarStyle.Marquee,
            MarqueeAnimationSpeed = 30,
            Dock = DockStyle.Bottom,
            Height = 24,
        };
        Controls.Add(bar);
    }
}
