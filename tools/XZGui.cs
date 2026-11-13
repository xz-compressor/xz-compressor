// XZGui.cs — XZ 极速压缩工具 · 图形界面版
// 独立单文件：内嵌 7z.exe / 7z.dll，无环境可运行。
// 编译: csc /nologo /optimize+ /codepage:65001 /target:winexe
//        /r:System.Windows.Forms.dll /r:System.Drawing.dll
//        /resource:7z.exe,sevenz.exe /resource:7z.dll,sevenz.dll
//        /out:XZGui.exe XZGui.cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace XZGui
{
    static class Core
    {
        public static string SevenZ;

        // 强制只释放内嵌引擎（无环境验证用）
        public static string ForceExtract()
        {
            string dir = Path.Combine(Path.GetTempPath(), "xzgui_emb_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(dir);
            Assembly asm = Assembly.GetExecutingAssembly();
            ExtractResource(asm, "sevenz.exe", Path.Combine(dir, "7z.exe"));
            ExtractResource(asm, "sevenz.dll", Path.Combine(dir, "7z.dll"));
            ExtractResource(asm, "sevenz.sfx", Path.Combine(dir, "7z.sfx"));
            string exe = Path.Combine(dir, "7z.exe");
            if (File.Exists(exe)) return exe;
            throw new Exception("内嵌引擎资源缺失或释放失败。");
        }

        public static string FindOrExtract()
        {
            // 1) 同目录（完整版释放平铺 / 便携）
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string cand = Path.Combine(baseDir, "7z.exe");
            if (File.Exists(cand)) return cand;
            // 2) tools 上一层
            cand = Path.Combine(baseDir, "..", "7z.exe");
            if (File.Exists(cand)) return Path.GetFullPath(cand);
            // 3) 注册表
            try
            {
                using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\7-Zip"))
                {
                    if (k != null)
                    {
                        string p = k.GetValue("Path") as string;
                        if (!string.IsNullOrEmpty(p) && File.Exists(Path.Combine(p, "7z.exe")))
                            return Path.Combine(p, "7z.exe");
                    }
                }
            }
            catch { }
            // 4) Program Files
            foreach (string pf in new[] {
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86) })
            {
                if (!string.IsNullOrEmpty(pf))
                {
                    string c = Path.Combine(pf, "7-Zip", "7z.exe");
                    if (File.Exists(c)) return c;
                }
            }
            // 5) 内嵌资源释放
            string dir = Path.Combine(Path.GetTempPath(), "xzgui_engine");
            try
            {
                Directory.CreateDirectory(dir);
                Assembly asm = Assembly.GetExecutingAssembly();
                ExtractResource(asm, "sevenz.exe", Path.Combine(dir, "7z.exe"));
                ExtractResource(asm, "sevenz.dll", Path.Combine(dir, "7z.dll"));
                ExtractResource(asm, "sevenz.sfx", Path.Combine(dir, "7z.sfx"));
                if (File.Exists(Path.Combine(dir, "7z.exe"))) return Path.Combine(dir, "7z.exe");
            }
            catch { }
            return null;
        }

        static void ExtractResource(Assembly asm, string name, string outPath)
        {
            string full = null;
            foreach (string n in asm.GetManifestResourceNames())
                if (n.EndsWith(name, StringComparison.OrdinalIgnoreCase)) { full = n; break; }
            if (full == null) return;
            using (Stream s = asm.GetManifestResourceStream(full))
            using (FileStream fs = new FileStream(outPath, FileMode.Create, FileAccess.Write))
                s.CopyTo(fs);
        }

        public static string Quote(string p) { return "\"" + (p ?? "").Trim('"') + "\""; }

        // 压缩参数（7z 命令行）
        public static List<string> BuildCompressArgs(string fmt, int level, string pass, bool headerEnc,
            string volume, bool solid, bool sfx, bool tarFirst, List<string> inputs, string outPath)
        {
            List<string> a = new List<string>();
            a.Add("a");
            a.Add("-y");
            a.Add("-mx=" + level);
            // 分卷
            if (!string.IsNullOrEmpty(volume)) { a.Add("-v" + volume); }
            // 密码
            if (!string.IsNullOrEmpty(pass))
            {
                a.Add("-p" + pass);
                if (headerEnc) a.Add("-mhe=on");
            }
            if (fmt == "7z")
            {
                a.Add("-t7z");
                if (solid) a.Add("-ms=on");
                if (sfx) a.Add("-sfx");
            }
            else if (fmt == "zip") a.Add("-tzip");
            else if (fmt == "xz") a.Add("-txz");
            else if (fmt == "gz") a.Add("-tgzip");
            else if (fmt == "bz2") a.Add("-tbzip2");
            else if (fmt == "tgz") a.Add("-ttar"); // 第一步先打 tar，调用方随后再 gzip
            a.Add(Quote(outPath));
            foreach (string inp in inputs) a.Add(Quote(inp));
            return a;
        }

        public static List<string> BuildExtractArgs(string archive, string outDir, string pass)
        {
            List<string> a = new List<string>();
            a.Add("x"); a.Add(Quote(archive)); a.Add("-y");
            a.Add("-o" + Quote(outDir.Trim('"')));
            if (!string.IsNullOrEmpty(pass)) a.Add("-p" + pass);
            return a;
        }

        public static int Run(string args, Action<string> onLine)
        {
            Ensure();
            ProcessStartInfo psi = new ProcessStartInfo(SevenZ, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = System.Text.Encoding.UTF8;
            using (Process p = Process.Start(psi))
            {
                p.OutputDataReceived += (s, e) => { if (e.Data != null && onLine != null) onLine(e.Data); };
                p.ErrorDataReceived += (s, e) => { if (e.Data != null && onLine != null) onLine(e.Data); };
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();
                return p.ExitCode;
            }
        }

        public static void Ensure()
        {
            if (SevenZ == null) SevenZ = FindOrExtract();
            if (SevenZ == null) throw new Exception("未找到 7-Zip 引擎，且内置引擎释放失败。");
        }

        // 自检测试（无窗口，供自动化验证）；embedded=true 强制用内嵌引擎
        public static int SelfTest(bool embedded)
        {
            string work = null;
            try
            {
                if (embedded) SevenZ = ForceExtract(); else Ensure();
                work = Path.Combine(Path.GetTempPath(), "xzgui_selftest_" + Guid.NewGuid().ToString("N").Substring(0, 8));
                Directory.CreateDirectory(work);
                string src = Path.Combine(work, "a.txt");
                File.WriteAllText(src, "hello-xzgui-selftest-中文测试-" + new string('x', 500));
                string zip = Path.Combine(work, "a.zip");
                int r1 = Run(string.Join(" ", BuildCompressArgs("zip", 9, "", false, "", false, false, false,
                    new List<string> { src }, zip)), null);
                string ext = Path.Combine(work, "out");
                Directory.CreateDirectory(ext);
                int r2 = Run(string.Join(" ", BuildExtractArgs(zip, ext, "")), null);
                bool ok = File.Exists(Path.Combine(ext, "a.txt"));
                Console.WriteLine("Engine=" + SevenZ);
                Console.WriteLine("Embedded=" + embedded);
                Console.WriteLine("CompressExit=" + r1 + " ExtractExit=" + r2 + " RoundTrip=" + ok);
                bool pass = (r1 == 0 && r2 == 0 && ok);
                // 内嵌模式额外验证 sfx 资源
                if (embedded && embedded && !File.Exists(Path.Combine(Path.GetDirectoryName(SevenZ), "7z.sfx")))
                {
                    Console.WriteLine("SFX resource missing");
                    pass = false;
                }
                return pass ? 0 : 2;
            }
            catch (Exception ex)
            {
                Console.WriteLine("SELFTEST-FAIL: " + ex.Message);
                return 3;
            }
            finally
            {
                try { if (work != null) Directory.Delete(work, true); } catch { }
            }
        }
    }

    public class MainForm : Form
    {
        ListBox lst;
        ComboBox cmbFmt, cmbLv, cmbVol;
        CheckBox chkSfx, chkSolid, chkShow, chkHeader;
        TextBox txtPass, txtPass2, txtOut;
        ProgressBar pb;
        Label lblStatus, lblPct;
        TextBox txtLog;
        Button btnGo, btnExtract;

        public MainForm()
        {
            Text = "XZ 极速压缩工具 · 图形界面 0.1";
            Width = 600; Height = 700;
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Microsoft YaHei UI", 9F);
            AllowDrop = true;
            BackColor = Color.White;
            BuildUi();
            DragEnter += (s, e) => { if (e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy; };
            DragDrop += (s, e) => {
                foreach (string f in (string[])e.Data.GetData(DataFormats.FileDrop))
                    if (!lst.Items.Contains(f)) lst.Items.Add(f);
            };
        }

        void BuildUi()
        {
            int y = 12, pad = 14;
            Label l1 = new Label { Text = "输入文件 / 文件夹（可拖入，可多选）：", Left = pad, Top = y, Width = 400 };
            Controls.Add(l1); y += 24;
            lst = new ListBox { Left = pad, Top = y, Width = 552, Height = 110, HorizontalScrollbar = true };
            Controls.Add(lst);
            Button bFile = MkBtn("添加文件", pad, y + 114, 110);
            Button bFolder = MkBtn("添加文件夹", pad + 118, y + 114, 110);
            Button bClear = MkBtn("清空", pad + 236, y + 114, 80);
            bFile.Click += (s, e) => {
                OpenFileDialog d = new OpenFileDialog { Multiselect = true, Title = "选择要压缩的文件" };
                if (d.ShowDialog() == DialogResult.OK) foreach (string f in d.FileNames) if (!lst.Items.Contains(f)) lst.Items.Add(f);
            };
            bFolder.Click += (s, e) => {
                FolderBrowserDialog d = new FolderBrowserDialog { Description = "选择要压缩的文件夹" };
                if (d.ShowDialog() == DialogResult.OK) if (!lst.Items.Contains(d.SelectedPath)) lst.Items.Add(d.SelectedPath);
            };
            bClear.Click += (s, e) => lst.Items.Clear();
            Controls.Add(bFile); Controls.Add(bFolder); Controls.Add(bClear);
            y += 150;

            GroupBox gb = new GroupBox { Text = "压缩选项", Left = pad, Top = y, Width = 552, Height = 230 };
            Controls.Add(gb);
            int gy = 24;
            gb.Controls.Add(new Label { Text = "格式：", Left = 12, Top = gy + 4, Width = 60 });
            cmbFmt = new ComboBox { Left = 70, Top = gy, Width = 120, DropDownStyle = ComboBoxStyle.DropDownList };
            cmbFmt.Items.AddRange(new object[] { "7z（推荐，压缩率高）", "zip（通用）", "xz（单文件极致）", "gz（单文件）", "bz2（单文件）", "tgz（文件夹/多文件）" });
            cmbFmt.SelectedIndex = 0;
            cmbFmt.SelectedIndexChanged += (s, e) => UpdateSfx();
            gb.Controls.Add(cmbFmt);
            gb.Controls.Add(new Label { Text = "档位：", Left = 210, Top = gy + 4, Width = 50 });
            cmbLv = new ComboBox { Left = 260, Top = gy, Width = 150, DropDownStyle = ComboBoxStyle.DropDownList };
            cmbLv.Items.AddRange(new object[] { "快速 L3", "标准 L6", "极限 L9" });
            cmbLv.SelectedIndex = 2;
            gb.Controls.Add(cmbLv);
            gy += 36;

            chkSfx = new CheckBox { Text = "生成自解压 EXE（仅 7z，双击即解压）", Left = 12, Top = gy, Width = 300 };
            gb.Controls.Add(chkSfx);
            chkSolid = new CheckBox { Text = "固实压缩（7z 大量小文件更省）", Left = 300, Top = gy, Width = 220, Checked = true };
            gb.Controls.Add(chkSolid);
            gy += 32;

            gb.Controls.Add(new Label { Text = "密码：", Left = 12, Top = gy + 4, Width = 50 });
            txtPass = new TextBox { Left = 66, Top = gy, Width = 150, PasswordChar = '●' };
            gb.Controls.Add(txtPass);
            gb.Controls.Add(new Label { Text = "确认：", Left = 226, Top = gy + 4, Width = 44 });
            txtPass2 = new TextBox { Left = 272, Top = gy, Width = 150, PasswordChar = '●' };
            gb.Controls.Add(txtPass2);
            chkShow = new CheckBox { Text = "显示", Left = 430, Top = gy, Width = 60 };
            chkShow.CheckedChanged += (s, e) => { char c = chkShow.Checked ? '\0' : '●'; txtPass.PasswordChar = c; txtPass2.PasswordChar = c; };
            gb.Controls.Add(chkShow);
            gy += 32;
            chkHeader = new CheckBox { Text = "加密文件名（7z 头部加密，更安全）", Left = 12, Top = gy, Width = 280, Checked = true };
            gb.Controls.Add(chkHeader);
            gb.Controls.Add(new Label { Text = "分卷：", Left = 300, Top = gy + 4, Width = 46 });
            cmbVol = new ComboBox { Left = 350, Top = gy, Width = 150, DropDownStyle = ComboBoxStyle.DropDownList };
            cmbVol.Items.AddRange(new object[] { "不分卷", "10m", "100m", "700m", "4400m", "自定义…" });
            cmbVol.SelectedIndex = 0;
            cmbVol.SelectedIndexChanged += (s, e) => {
                if (cmbVol.SelectedIndex == 5)
                {
                    string v = InputDialog.Ask("输入分卷大小（如 50m / 1g）：", "分卷大小", "100m");
                    if (!string.IsNullOrEmpty(v)) { cmbVol.Items.Insert(5, v); cmbVol.SelectedItem = v; }
                }
            };
            gb.Controls.Add(cmbVol);
            gy += 38;

            gb.Controls.Add(new Label { Text = "输出目录：", Left = 12, Top = gy + 4, Width = 80 });
            txtOut = new TextBox { Left = 92, Top = gy, Width = 340 };
            gb.Controls.Add(txtOut);
            Button bOut = new Button { Text = "浏览…", Left = 440, Top = gy - 1, Width = 80 };
            bOut.Click += (s, e) => {
                FolderBrowserDialog d = new FolderBrowserDialog { Description = "选择输出目录" };
                if (d.ShowDialog() == DialogResult.OK) txtOut.Text = d.SelectedPath;
            };
            gb.Controls.Add(bOut);
            y += 240;

            btnGo = MkBtn("开始压缩", pad, y, 180);
            btnGo.Height = 34;
            btnExtract = MkBtn("解压压缩包…", pad + 196, y, 140);
            btnExtract.Height = 34;
            btnGo.Click += (s, e) => DoCompress();
            btnExtract.Click += (s, e) => DoExtract();
            Controls.Add(btnGo); Controls.Add(btnExtract);
            y += 42;

            pb = new ProgressBar { Left = pad, Top = y, Width = 552, Height = 18 };
            Controls.Add(pb); y += 22;
            lblPct = new Label { Text = "", Left = pad, Top = y, Width = 100 };
            lblStatus = new Label { Text = "就绪", Left = 110, Top = y, Width = 450 };
            Controls.Add(lblPct); Controls.Add(lblStatus); y += 26;
            txtLog = new TextBox { Left = pad, Top = y, Width = 552, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true, BackColor = Color.FromArgb(248, 248, 248) };
            Controls.Add(txtLog);
            UpdateSfx();
        }

        Button MkBtn(string text, int x, int y, int w)
        {
            return new Button { Text = text, Left = x, Top = y, Width = w, Height = 26 };
        }

        void UpdateSfx()
        {
            bool is7z = cmbFmt.SelectedIndex == 0;
            chkSfx.Enabled = is7z;
            if (!is7z) chkSfx.Checked = false;
            chkSolid.Enabled = is7z;
            chkHeader.Enabled = (cmbFmt.SelectedIndex == 0 || cmbFmt.SelectedIndex == 1);
        }

        string FmtCode()
        {
            return new[] { "7z", "zip", "xz", "gz", "bz2", "tgz" }[cmbFmt.SelectedIndex];
        }

        void Log(string s) { txtLog.AppendText(s + "\r\n"); }

        bool ValidateCommon(out List<string> inputs)
        {
            inputs = new List<string>();
            foreach (object o in lst.Items) inputs.Add(o.ToString());
            if (inputs.Count == 0) { MessageBox.Show("请先添加文件或文件夹。", "提示"); return false; }
            if (txtPass.Text != txtPass2.Text) { MessageBox.Show("两次输入的密码不一致。", "提示"); return false; }
            if (!string.IsNullOrEmpty(txtPass.Text) && txtPass.Text.Length < 4)
                if (MessageBox.Show("密码较短（建议 8 位以上），仍要继续？", "弱密码提示", MessageBoxButtons.YesNo) == DialogResult.No) return false;
            string fmt = FmtCode();
            bool multi = inputs.Count > 1;
            bool folder = false;
            foreach (string f in inputs) if (Directory.Exists(f)) folder = true;
            if ((fmt == "xz" || fmt == "gz" || fmt == "bz2") && (multi || folder))
            {
                MessageBox.Show("xz / gz / bz2 只能压缩单个文件。\n多文件或文件夹请用 7z、zip 或 tgz。", "格式限制");
                return false;
            }
            return true;
        }

        void DoCompress()
        {
            List<string> inputs;
            if (!ValidateCommon(out inputs)) return;
            string fmt = FmtCode();
            int level = new[] { 3, 6, 9 }[cmbLv.SelectedIndex];
            string pass = txtPass.Text;
            string vol = null;
            if (cmbVol.SelectedIndex >= 1 && cmbVol.SelectedItem != null)
            {
                string v = cmbVol.SelectedItem.ToString();
                if (v != "不分卷" && v != "自定义…") vol = v;
            }
            bool sfx = chkSfx.Checked;
            bool solid = chkSolid.Checked;
            bool header = chkHeader.Checked;

            string first = inputs[0];
            string baseName = (inputs.Count == 1 ? Path.GetFileNameWithoutExtension(first.TrimEnd('\\')) : "archive");
            string outDir = string.IsNullOrEmpty(txtOut.Text) ? Path.GetDirectoryName(first.TrimEnd('\\')) : txtOut.Text;
            if (string.IsNullOrEmpty(outDir) || !Directory.Exists(outDir)) outDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            string ext = sfx ? "exe" : fmt;
            string outPath = Path.Combine(outDir, baseName + "_L" + level + "." + ext);

            string outFinal = outPath;
            RunAsync(() =>
            {
                SetStatus("正在压缩 (" + fmt + " L" + level + ") …");
                List<string> args;
                if (fmt == "tgz")
                {
                    string tar = Path.Combine(outDir, baseName + "_L" + level + ".tar");
                    args = Core.BuildCompressArgs("tgz", level, pass, false, vol, solid, false, true, inputs, tar);
                    int r = Core.Run(string.Join(" ", args), OnLine);
                    if (r != 0) { SetStatus("tar 打包失败 " + r); return; }
                    string gz = Path.Combine(outDir, baseName + "_L" + level + ".tar.gz");
                    int r2 = Core.Run(string.Join(" ", Core.BuildCompressArgs("gz", level, pass, false, "", false, false, false,
                        new List<string> { tar }, gz)), OnLine);
                    try { File.Delete(tar); } catch { }
                    Finish(r2 == 0, gz);
                }
                else
                {
                    args = Core.BuildCompressArgs(fmt, level, pass, header, vol, solid, sfx, false, inputs, outPath);
                    int r = Core.Run(string.Join(" ", args), OnLine);
                    Finish(r == 0, outFinal);
                }
            });
        }

        void DoExtract()
        {
            OpenFileDialog d = new OpenFileDialog {
                Title = "选择要解压的压缩包",
                Filter = "压缩包|*.zip;*.7z;*.xz;*.gz;*.bz2;*.tgz;*.tar;*.tar.gz;*.rar;*.exe|所有文件|*.*"
            };
            if (d.ShowDialog() != DialogResult.OK) return;
            FolderBrowserDialog fd = new FolderBrowserDialog { Description = "选择解压到的目录" };
            if (fd.ShowDialog() != DialogResult.OK) return;
            string pass = InputDialog.Ask("如有密码请输入（无密码留空）：", "解压密码", "", true);
            string arc = d.FileName, outDir = Path.Combine(fd.SelectedPath, Path.GetFileNameWithoutExtension(arc));
            Directory.CreateDirectory(outDir);
            RunAsync(() =>
            {
                SetStatus("正在解压 …");
                int r = Core.Run(string.Join(" ", Core.BuildExtractArgs(arc, outDir, pass)), OnLine);
                Finish(r == 0, outDir);
            });
        }

        void Finish(bool ok, string target)
        {
            Invoke((MethodInvoker)delegate {
                pb.Value = ok ? 100 : 0;
                lblPct.Text = ok ? "100%" : "";
                SetStatus(ok ? "完成：" + target : "失败，请查看日志");
                if (ok) MessageBox.Show("完成：\n" + target, "XZ 压缩工具");
                btnGo.Enabled = btnExtract.Enabled = true;
            });
        }

        void OnLine(string line)
        {
            Invoke((MethodInvoker)delegate {
                Log(line);
                Match m = Regex.Match(line, @"(\d{1,3})\s*%");
                if (m.Success)
                {
                    int p;
                    if (int.TryParse(m.Groups[1].Value, out p) && p >= 0 && p <= 100) { pb.Value = p; lblPct.Text = p + "%"; }
                }
            });
        }

        void SetStatus(string s) { try { Invoke((MethodInvoker)delegate { lblStatus.Text = s; }); } catch { } }

        void RunAsync(ThreadStart work)
        {
            btnGo.Enabled = btnExtract.Enabled = false;
            pb.Value = 0; lblPct.Text = "";
            Thread t = new Thread(work);
            t.IsBackground = true;
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
        }
    }

    // 简易输入框（用于自定义分卷/密码）
    static class InputDialog
    {
        public static string Ask(string text, string caption, string def, bool password = false)
        {
            Form f = new Form { Text = caption, Width = 380, Height = 170, StartPosition = FormStartPosition.CenterParent, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
            Label l = new Label { Text = text, Left = 12, Top = 12, Width = 340 };
            TextBox tb = new TextBox { Left = 12, Top = 38, Width = 340, Text = def };
            if (password) tb.PasswordChar = '●';
            Button ok = new Button { Text = "确定", Left = 190, Top = 78, Width = 76, DialogResult = DialogResult.OK };
            Button ca = new Button { Text = "取消", Left = 276, Top = 78, Width = 76, DialogResult = DialogResult.Cancel };
            f.Controls.AddRange(new Control[] { l, tb, ok, ca });
            f.AcceptButton = ok; f.CancelButton = ca;
            return f.ShowDialog() == DialogResult.OK ? tb.Text : null;
        }
    }

    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            if (args.Length > 0 && (args[0] == "--selftest" || args[0] == "/selftest"))
            {
                Environment.ExitCode = Core.SelfTest(false);
                return;
            }
            if (args.Length > 0 && (args[0] == "--selftest-embedded" || args[0] == "/selftest-embedded"))
            {
                Environment.ExitCode = Core.SelfTest(true);
                return;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
