using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace X47Setup
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupForm());
        }
    }

    sealed class SetupForm : Form
    {
        static readonly Color Bg = Color.FromArgb(20, 17, 15);
        static readonly Color Card = Color.FromArgb(30, 25, 22);
        static readonly Color Ink = Color.FromArgb(245, 239, 232);
        static readonly Color Muted = Color.FromArgb(196, 184, 174);
        static readonly Color Line = Color.FromArgb(58, 49, 44);
        static readonly Color Teal = Color.FromArgb(45, 212, 191);
        static readonly Color Rose = Color.FromArgb(251, 113, 133);
        static readonly Color Warn = Color.FromArgb(245, 158, 11);

        readonly Panel[] _pages;
        readonly Label _stepLabel;
        readonly Button _back;
        readonly Button _next;
        readonly Button _cancel;

        RadioButton _thX47;
        RadioButton _thXp;
        RadioButton _thXpR;
        RadioButton _thVista;
        RadioButton _th10;
        RadioButton _th11;
        Label _themeHint;

        CheckBox _snap;
        CheckBox _wall;
        CheckBox _debloat;
        CheckBox _privacy;
        CheckBox _ids;
        CheckBox _security;
        CheckBox _anon;
        CheckBox _themeOn;
        CheckBox _bitlocker;
        CheckBox _guid;
        Label _review;

        int _page;
        bool _busy;

        public SetupForm()
        {
            Text = "X47-Win Setup";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = true;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(740, 560);
            BackColor = Bg;
            ForeColor = Ink;
            Font = new Font("Segoe UI", 10f, FontStyle.Regular);
            try
            {
                string ico = Path.Combine(AppDir(), "setup", "x47.ico");
                if (File.Exists(ico)) Icon = new Icon(ico);
            }
            catch { }

            Panel header = Band(0, 0, 740, 72);
            Label brand = Title("X47-Win Setup", 20, 14, 420, 28, 16f, true);
            brand.ForeColor = Teal;
            _stepLabel = Title("1 / 4  Welcome", 20, 42, 500, 22, 9.5f, false);
            _stepLabel.ForeColor = Muted;
            header.Controls.Add(brand);
            header.Controls.Add(_stepLabel);
            Controls.Add(header);

            _pages = new Panel[]
            {
                PageWelcome(),
                PageTheme(),
                PageFeatures(),
                PageReview()
            };
            for (int i = 0; i < _pages.Length; i++)
            {
                _pages[i].Location = new Point(0, 72);
                _pages[i].Size = new Size(740, 420);
                _pages[i].Visible = (i == 0);
                Controls.Add(_pages[i]);
            }

            Panel footer = Band(0, 492, 740, 68);
            footer.Paint += delegate(object s, PaintEventArgs e)
            {
                e.Graphics.DrawLine(new Pen(Line), 0, 0, 740, 0);
            };

            _cancel = Ghost("Cancel", 20, 16, 100);
            _cancel.Click += delegate { Close(); };
            _back = Ghost("Back", 430, 16, 90);
            _back.Enabled = false;
            _back.Click += delegate { ShowPage(_page - 1); };
            _next = Solid("Next", 530, 16, 190);
            _next.Click += delegate { OnNext(); };

            footer.Controls.Add(_cancel);
            footer.Controls.Add(_back);
            footer.Controls.Add(_next);
            Controls.Add(footer);
        }

        Panel PageWelcome()
        {
            Panel p = Page();
            p.Controls.Add(Title("Install a privacy kit on this Windows 11 PC", 28, 18, 680, 28, 13f, true));

            p.Controls.Add(Body(
                "The setup GUI picks a default look and which features to apply. " +
                "Nothing is written until you click Install on the last page.",
                28, 56, 680, 48));

            p.Controls.Add(CardText(28, 118, 684, 250,
                "Snapshot first — Windows restore point plus rollback snapshot, so you can undo.\n\n" +
                "Does not format the disk or delete Documents, Pictures, or Desktop.\n\n" +
                "BitLocker stays off unless you opt in. VeraCrypt is also fine — install it yourself from veracrypt.fr. Do not stack both on the same volume.\n\n" +
                "Store, OneDrive, Xbox, and Microsoft sign-in will likely break if you keep anonymity on. Defender and Windows Update stay on.\n\n" +
                "Undo later with Rollback-X47Windows.bat"));
            return p;
        }

        Panel PageTheme()
        {
            Panel p = Page();
            p.Controls.Add(Title("Default look", 28, 14, 680, 26, 13f, true));
            p.Controls.Add(Body("This is applied at the end of install. You can change it later with Apply-X47Theme.", 28, 42, 680, 36));

            _thX47 = Radio("X47 circuit  (recommended default)", "x47", 36, 88);
            _thX47.Checked = true;
            _thXp = Radio("Windows XP", "xp", 36, 124);
            _thXpR = Radio("Remastered XP", "xp-remastered", 36, 160);
            _thVista = Radio("Windows Vista", "vista", 36, 196);
            _th10 = Radio("Windows 10", "win10", 36, 232);
            _th11 = Radio("Windows 11 stock", "win11", 36, 268);

            EventHandler hint = delegate { UpdateThemeHint(); };
            _thX47.CheckedChanged += hint;
            _thXp.CheckedChanged += hint;
            _thXpR.CheckedChanged += hint;
            _thVista.CheckedChanged += hint;
            _th10.CheckedChanged += hint;
            _th11.CheckedChanged += hint;

            p.Controls.Add(_thX47);
            p.Controls.Add(_thXp);
            p.Controls.Add(_thXpR);
            p.Controls.Add(_thVista);
            p.Controls.Add(_th10);
            p.Controls.Add(_th11);

            _themeHint = Body("", 28, 314, 684, 88);
            _themeHint.ForeColor = Teal;
            p.Controls.Add(_themeHint);
            UpdateThemeHint();
            return p;
        }

        Panel PageFeatures()
        {
            Panel p = Page();
            p.Controls.Add(Title("What to install", 28, 10, 680, 24, 13f, true));
            p.Controls.Add(Body("Defaults match a full privacy pass. Uncheck anything you do not want.", 28, 36, 680, 22));

            _snap = Tick("Snapshot first (restore point + rollback journal)", 36, 68, true);
            _wall = Tick("Set wallpaper for the selected look", 36, 98, true);
            _debloat = Tick("Debloat — Xbox, Widgets, Copilot, consumer junk", 36, 128, true);
            _privacy = Tick("Privacy — telemetry Required, ads and location off", 36, 158, true);
            _ids = Tick("Rotate advertising ID and SQM ID (MachineGuid left alone)", 36, 188, true);
            _security = Tick("Security — inbound firewall, RDP off, Defender stays", 36, 218, true);
            _anon = Tick("Max-offline anonymity — block MSA / Store / OneDrive / hosts", 36, 248, true);
            _themeOn = Tick("Apply the selected look (Open-Shell / ExplorerPatcher as needed)", 36, 278, true);

            Label opt = Title("Optional — off by default", 28, 318, 400, 22, 10f, true);
            opt.ForeColor = Warn;
            p.Controls.Add(opt);

            _bitlocker = Tick("BitLocker + pre-boot PIN  (Windows 11 Pro, full volume)", 36, 344, false);
            _guid = Tick("Spoof MachineGuid  (breaks activation; does not hide hardware)", 36, 374, false);
            _bitlocker.ForeColor = Warn;
            _guid.ForeColor = Rose;

            p.Controls.Add(_snap);
            p.Controls.Add(_wall);
            p.Controls.Add(_debloat);
            p.Controls.Add(_privacy);
            p.Controls.Add(_ids);
            p.Controls.Add(_security);
            p.Controls.Add(_anon);
            p.Controls.Add(_themeOn);
            p.Controls.Add(_bitlocker);
            p.Controls.Add(_guid);
            return p;
        }

        Panel PageReview()
        {
            Panel p = Page();
            p.Controls.Add(Title("Review and install", 28, 14, 680, 26, 13f, true));
            _review = CardText(28, 50, 684, 340, "");
            p.Controls.Add(_review);
            return p;
        }

        void UpdateThemeHint()
        {
            if (_themeHint == null) return;
            switch (SelectedTheme())
            {
                case "xp":
                    _themeHint.Text = "Original hills wallpaper, Luna-blue accent, classic Start (Open-Shell). Window chrome stays Windows 11.";
                    break;
                case "xp-remastered":
                    _themeHint.Text = "XP bones with a two-column Start, search, large icons, and dusk 4K hills.";
                    break;
                case "vista":
                    _themeHint.Text = "Aurora wallpaper, Aero-style Start, transparency, dark system theme.";
                    break;
                case "win10":
                    _themeHint.Text = "ExplorerPatcher Windows 10 taskbar and bloom wallpaper.";
                    break;
                case "win11":
                    _themeHint.Text = "Stock Windows 11 Start and taskbar. Circuit or default wallpaper only if wallpaper is on.";
                    break;
                default:
                    _themeHint.Text = "Teal X47 circuit wallpaper and accent. Stock Windows 11 chrome. This is the default.";
                    break;
            }
        }

        string SelectedTheme()
        {
            if (_thXp != null && _thXp.Checked) return "xp";
            if (_thXpR != null && _thXpR.Checked) return "xp-remastered";
            if (_thVista != null && _thVista.Checked) return "vista";
            if (_th10 != null && _th10.Checked) return "win10";
            if (_th11 != null && _th11.Checked) return "win11";
            return "x47";
        }

        void RefreshReview()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("Look:  " + ThemeLabel(SelectedTheme()));
            sb.AppendLine();
            sb.AppendLine(OnOff(_snap.Checked) + "  Snapshot / rollback");
            sb.AppendLine(OnOff(_wall.Checked) + "  Wallpaper");
            sb.AppendLine(OnOff(_debloat.Checked) + "  Debloat");
            sb.AppendLine(OnOff(_privacy.Checked) + "  Privacy");
            sb.AppendLine(OnOff(_ids.Checked) + "  Rotate advertising + SQM IDs");
            sb.AppendLine(OnOff(_security.Checked) + "  Security hardening");
            sb.AppendLine(OnOff(_anon.Checked) + "  Max-offline anonymity");
            sb.AppendLine(OnOff(_themeOn.Checked) + "  Apply look");
            sb.AppendLine(OnOff(_bitlocker.Checked) + "  BitLocker + PIN");
            sb.AppendLine(OnOff(_guid.Checked) + "  Spoof MachineGuid");
            sb.AppendLine();
            sb.AppendLine("A PowerShell window will open and do the work. Leave it open until it finishes.");
            if (_bitlocker.Checked)
                sb.AppendLine("BitLocker will ask for a 6+ digit PIN in that window. Have a USB stick ready.");
            if (_guid.Checked)
                sb.AppendLine("MachineGuid spoof will break activation. Board UUID and TPM stay.");
            if (!_snap.Checked)
                sb.AppendLine("Warning: snapshot is off. Rollback will have nothing new to restore.");
            _review.Text = sb.ToString();
        }

        static string ThemeLabel(string id)
        {
            switch (id)
            {
                case "xp": return "Windows XP";
                case "xp-remastered": return "Remastered XP";
                case "vista": return "Windows Vista";
                case "win10": return "Windows 10";
                case "win11": return "Windows 11 stock";
                default: return "X47 circuit (default)";
            }
        }

        static string OnOff(bool on)
        {
            return on ? "[ON] " : "[off]";
        }

        void ShowPage(int index)
        {
            if (index < 0 || index >= _pages.Length) return;
            _page = index;
            for (int i = 0; i < _pages.Length; i++)
                _pages[i].Visible = (i == _page);

            string[] names = { "Welcome", "Default look", "Features", "Install" };
            _stepLabel.Text = string.Format("{0} / {1}   {2}", _page + 1, _pages.Length, names[_page]);
            _back.Enabled = _page > 0 && !_busy;
            _cancel.Enabled = !_busy;

            if (_page == 3)
            {
                RefreshReview();
                _next.Text = "Install";
            }
            else
            {
                _next.Text = "Next";
            }
        }

        void OnNext()
        {
            if (_busy) return;
            if (_page < 3)
            {
                ShowPage(_page + 1);
                return;
            }
            StartInstall();
        }

        void StartInstall()
        {
            if (_guid.Checked)
            {
                DialogResult g = MessageBox.Show(this,
                    "MachineGuid spoof is optional and you turned it ON.\n\n" +
                    "It replaces HKLM\\SOFTWARE\\Microsoft\\Cryptography\\MachineGuid.\n" +
                    "Activation WILL break. BitLocker and Windows Update can break.\n" +
                    "The board UUID and TPM are NOT changed. The PC is still identifiable.\n" +
                    "Rollback can put the old GUID back if rollback snapshot still exists.\n\n" +
                    "Continue with MachineGuid spoof?",
                    "X47-Win — MachineGuid warning",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
                if (g != DialogResult.Yes)
                {
                    _guid.Checked = false;
                    RefreshReview();
                    return;
                }
            }

            if (_bitlocker.Checked)
            {
                DialogResult b = MessageBox.Show(this,
                    "BitLocker will encrypt the Windows volume (XTS-AES 256, TPM + PIN).\n\n" +
                    "Stay on AC power. Have a USB stick ready.\n" +
                    "Photograph the 48-digit recovery key.\n" +
                    "The PIN only unlocks Windows. Ubuntu LUKS stays separate.\n" +
                    "Do not also put VeraCrypt on this same volume.\n\n" +
                    "Continue with BitLocker?",
                    "X47-Win — BitLocker",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Information);
                if (b != DialogResult.Yes)
                {
                    _bitlocker.Checked = false;
                    RefreshReview();
                    return;
                }
            }

            string kit = KitRoot();
            string script = Path.Combine(kit, "Install-X47Windows.ps1");
            if (!File.Exists(script))
            {
                MessageBox.Show(this,
                    "Could not find Install-X47Windows.ps1.\nLooked in:\n" + kit,
                    "X47-Win Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            string args = BuildArgs(script);
            string ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell", "v1.0", "powershell.exe");
            if (!File.Exists(ps))
                ps = "powershell.exe";

            _busy = true;
            _next.Enabled = false;
            _back.Enabled = false;
            _cancel.Enabled = false;
            _next.Text = "Installing…";
            _review.Text = _review.Text + "\n\nRunning the kit in a PowerShell window. Leave that window open.";
            Refresh();

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = ps;
            psi.Arguments = args;
            psi.WorkingDirectory = kit;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = false;

            Process proc = new Process();
            proc.StartInfo = psi;
            try
            {
                proc.Start();
                proc.WaitForExit();
            }
            catch (Exception ex)
            {
                _busy = false;
                ShowPage(3);
                _next.Enabled = true;
                MessageBox.Show(this, "Could not start PowerShell:\n" + ex.Message,
                    "X47-Win Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            _busy = false;
            if (proc.ExitCode == 0)
            {
                string rollbackBat = Path.Combine(kit, "Rollback-X47Windows.bat");
                string themeBat = Path.Combine(kit, "Apply-X47Theme.bat");
                MessageBox.Show(this,
                    "X47-Win finished.\n\n" +
                    "Encrypt the disk when you can (BitLocker or VeraCrypt) if you did not already.\n" +
                    "Undo: " + rollbackBat + "\n" +
                    "Change the look later: " + themeBat,
                    "X47-Win Setup", MessageBoxButtons.OK, MessageBoxIcon.Information);
                Close();
            }
            else
            {
                ShowPage(3);
                _next.Enabled = true;
                _next.Text = "Install";
                _back.Enabled = true;
                _cancel.Enabled = true;
                string logDir = Path.Combine(kit, "logs");
                MessageBox.Show(this,
                    "The kit reported an error (exit " + proc.ExitCode + ").\n" +
                    "Scroll the PowerShell window or open:\n" + logDir,
                    "X47-Win Setup", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        string BuildArgs(string script)
        {
            StringBuilder a = new StringBuilder();
            a.Append("-NoProfile -ExecutionPolicy Bypass -File \"");
            a.Append(script);
            a.Append("\" -Quiet -Theme ");
            a.Append(SelectedTheme());
            if (!_snap.Checked) a.Append(" -SkipSnapshot");
            if (!_wall.Checked) a.Append(" -SkipWallpaper");
            if (!_debloat.Checked) a.Append(" -SkipDebloat");
            if (!_privacy.Checked) a.Append(" -SkipPrivacy");
            if (!_ids.Checked) a.Append(" -SkipIdentifiers");
            if (!_security.Checked) a.Append(" -SkipSecurity");
            if (!_anon.Checked) a.Append(" -SkipAnonymity");
            if (!_themeOn.Checked) a.Append(" -SkipTheme");
            if (_bitlocker.Checked) a.Append(" -EnableBitLocker");
            if (_guid.Checked) a.Append(" -SpoofMachineGuid");
            return a.ToString();
        }

        static string AppDir()
        {
            return Path.GetDirectoryName(Application.ExecutablePath);
        }

        static string KitRoot()
        {
            string here = AppDir();
            if (File.Exists(Path.Combine(here, "Install-X47Windows.ps1")))
                return here;
            string parent = Directory.GetParent(here) != null ? Directory.GetParent(here).FullName : here;
            if (File.Exists(Path.Combine(parent, "Install-X47Windows.ps1")))
                return parent;
            if (File.Exists(@"C:\X47\Install-X47Windows.ps1"))
                return @"C:\X47";
            return here;
        }

        Panel Page()
        {
            Panel p = new Panel();
            p.BackColor = Bg;
            return p;
        }

        Panel Band(int x, int y, int w, int h)
        {
            Panel p = new Panel();
            p.Location = new Point(x, y);
            p.Size = new Size(w, h);
            p.BackColor = Card;
            return p;
        }

        Label Title(string text, int x, int y, int w, int h, float size, bool bold)
        {
            Label l = new Label();
            l.Text = text;
            l.Location = new Point(x, y);
            l.Size = new Size(w, h);
            l.ForeColor = Ink;
            l.BackColor = Color.Transparent;
            l.Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular);
            return l;
        }

        Label Body(string text, int x, int y, int w, int h)
        {
            Label l = Title(text, x, y, w, h, 10f, false);
            l.ForeColor = Muted;
            return l;
        }

        Label CardText(int x, int y, int w, int h, string text)
        {
            Label l = new Label();
            l.Text = text;
            l.Location = new Point(x, y);
            l.Size = new Size(w, h);
            l.Padding = new Padding(14, 12, 14, 12);
            l.ForeColor = Ink;
            l.BackColor = Card;
            l.Font = new Font("Segoe UI", 10f, FontStyle.Regular);
            return l;
        }

        RadioButton Radio(string text, string name, int x, int y)
        {
            RadioButton r = new RadioButton();
            r.Text = text;
            r.Name = name;
            r.Location = new Point(x, y);
            r.Size = new Size(640, 28);
            r.ForeColor = Ink;
            r.BackColor = Bg;
            r.FlatStyle = FlatStyle.Flat;
            return r;
        }

        CheckBox Tick(string text, int x, int y, bool on)
        {
            CheckBox c = new CheckBox();
            c.Text = text;
            c.Location = new Point(x, y);
            c.Size = new Size(670, 26);
            c.Checked = on;
            c.ForeColor = Ink;
            c.BackColor = Bg;
            c.FlatStyle = FlatStyle.Flat;
            return c;
        }

        Button Ghost(string text, int x, int y, int w)
        {
            Button b = new Button();
            b.Text = text;
            b.Location = new Point(x, y);
            b.Size = new Size(w, 36);
            b.FlatStyle = FlatStyle.Flat;
            b.FlatAppearance.BorderColor = Line;
            b.BackColor = Card;
            b.ForeColor = Ink;
            b.Cursor = Cursors.Hand;
            return b;
        }

        Button Solid(string text, int x, int y, int w)
        {
            Button b = Ghost(text, x, y, w);
            b.BackColor = Color.FromArgb(15, 90, 80);
            b.ForeColor = Color.White;
            b.FlatAppearance.BorderColor = Teal;
            b.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            return b;
        }
    }
}
