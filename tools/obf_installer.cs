using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace XZObf {

  public class Rec { public string Rel; public byte[] Data; public byte[] Sha; }

  public class Result {
    public bool Success; public string Error = ""; public int Count; public string Entry = "";
  }

  static class Core {

    static int FindBytes(byte[] all, string text, int from, int to) {
      byte[] m = Encoding.ASCII.GetBytes(text);
      for (int i = from; i <= to - m.Length; i++) {
        bool ok = true;
        for (int j = 0; j < m.Length; j++) if (all[i + j] != m[j]) { ok = false; break; }
        if (ok) return i;
      }
      return -1;
    }

    public static List<Rec> ReadPayload() {
      string exe = Assembly.GetExecutingAssembly().Location;
      byte[] all = File.ReadAllBytes(exe);
      int endPos = FindBytes(all, "XZEND", 0, all.Length);
      if (endPos < 0) throw new Exception("找不到安装数据结尾标记");
      int startPos = FindBytes(all, "XZOBF", 0, endPos);
      if (startPos < 0) throw new Exception("找不到安装数据起始标记");
      int pos = startPos + 5;
      int n = BitConverter.ToInt32(all, pos); pos += 4;
      var list = new List<Rec>();
      for (int r = 0; r < n; r++) {
        int relLen = BitConverter.ToInt32(all, pos); pos += 4;
        string rel = Encoding.UTF8.GetString(all, pos, relLen); pos += relLen;
        int dataLen = BitConverter.ToInt32(all, pos); pos += 4;
        byte[] sha = new byte[32];
        Buffer.BlockCopy(all, pos, sha, 0, 32); pos += 32;
        byte[] data = new byte[dataLen];
        Buffer.BlockCopy(all, pos, data, 0, dataLen); pos += dataLen;
        list.Add(new Rec { Rel = rel, Data = data, Sha = sha });
      }
      return list;
    }

    public static Result Install(List<Rec> recs, string dir, bool desktop, bool startMenu, Action<string,int> prog) {
      var res = new Result();
      try {
        int done = 0;
        foreach (var r in recs) {
          string rel = r.Rel.Replace('/', Path.DirectorySeparatorChar);
          string target = Path.Combine(dir, rel);
          string tdir = Path.GetDirectoryName(target);
          if (!Directory.Exists(tdir)) Directory.CreateDirectory(tdir);
          File.WriteAllBytes(target, r.Data);
          byte[] got;
          using (var sha = SHA256.Create()) got = sha.ComputeHash(r.Data);
          if (!BytesEqual(got, r.Sha)) throw new Exception("文件校验失败：" + r.Rel);
          if (r.Rel.IndexOf("启动压缩工具", StringComparison.OrdinalIgnoreCase) >= 0) res.Entry = target;
          done++;
          if (prog != null) prog(r.Rel, done);
        }
        if (string.IsNullOrEmpty(res.Entry)) {
          foreach (var r in recs) {
            if (r.Rel.IndexOf("xz-compressor.cmd", StringComparison.OrdinalIgnoreCase) >= 0) {
              res.Entry = Path.Combine(dir, r.Rel.Replace('/', Path.DirectorySeparatorChar));
              break;
            }
          }
        }
        if (desktop) CreateShortcut(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), AppInfo.Name, res.Entry);
        if (startMenu) {
          string sm = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu), "Programs");
          CreateShortcut(sm, AppInfo.Name, res.Entry);
          // 开始菜单卸载快捷方式
          CreateUninstallShortcut(sm, dir);
        }
        SetupMaintenance(dir, res.Entry);
        res.Success = true; res.Count = done;
      } catch (Exception ex) {
        res.Success = false; res.Error = ex.Message;
      }
      return res;
    }

    static bool BytesEqual(byte[] a, byte[] b) {
      if (a.Length != b.Length) return false;
      for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
      return true;
    }

    public static void CreateShortcut(string dir, string name, string target) {
      if (string.IsNullOrEmpty(target)) return;
      try {
        Type t = Type.GetTypeFromProgID("WScript.Shell");
        dynamic shell = Activator.CreateInstance(t);
        string lnk = Path.Combine(dir, name + ".lnk");
        dynamic sc = shell.CreateShortcut(lnk);
        sc.TargetPath = target;
        sc.WorkingDirectory = Path.GetDirectoryName(target);
        sc.Description = AppInfo.Name;
        sc.Save();
      } catch { }
    }

    public static void CreateUninstallShortcut(string dir, string installDir) {
      try {
        string unins = Path.Combine(installDir, "unins.exe");
        if (!File.Exists(unins)) return;
        Type t = Type.GetTypeFromProgID("WScript.Shell");
        dynamic shell = Activator.CreateInstance(t);
        string lnk = Path.Combine(dir, "卸载 " + AppInfo.Name + ".lnk");
        dynamic sc = shell.CreateShortcut(lnk);
        sc.TargetPath = unins;
        sc.Arguments = "/uninstall";
        sc.WorkingDirectory = installDir;
        sc.Save();
      } catch { }
    }

    public static void SetupMaintenance(string dir, string entry) {
      try {
        string self = Assembly.GetExecutingAssembly().Location;
        string unins = Path.Combine(dir, "unins.exe");
        if (!string.Equals(self, unins, StringComparison.OrdinalIgnoreCase)) {
          try { File.Copy(self, unins, true); } catch { }
        }
        string icon = File.Exists(unins) ? unins : entry;
        using (RegistryKey k = Registry.CurrentUser.CreateSubKey(AppInfo.RegKey)) {
          k.SetValue("DisplayName", AppInfo.Name + " 压缩工具", RegistryValueKind.String);
          k.SetValue("DisplayVersion", AppInfo.Version, RegistryValueKind.String);
          k.SetValue("Publisher", "XZ", RegistryValueKind.String);
          k.SetValue("InstallLocation", dir, RegistryValueKind.String);
          if (!string.IsNullOrEmpty(icon)) k.SetValue("DisplayIcon", icon, RegistryValueKind.String);
          if (File.Exists(unins)) {
            k.SetValue("UninstallString", "\"" + unins + "\" /uninstall", RegistryValueKind.String);
            k.SetValue("QuietUninstallString", "\"" + unins + "\" /S /uninstall", RegistryValueKind.String);
            k.SetValue("ModifyPath", "\"" + unins + "\" /modify", RegistryValueKind.String);
          }
          k.SetValue("NoModify", 0, RegistryValueKind.DWord);
          k.SetValue("NoRepair", 0, RegistryValueKind.DWord);
          k.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"), RegistryValueKind.String);
        }
      } catch { }
    }

    public static string GetInstallDir() {
      try {
        using (RegistryKey k = Registry.CurrentUser.OpenSubKey(AppInfo.RegKey)) {
          if (k == null) return null;
          object v = k.GetValue("InstallLocation");
          return v == null ? null : v.ToString();
        }
      } catch { return null; }
    }

    public static void RemoveReg() {
      try { Registry.CurrentUser.DeleteSubKeyTree(AppInfo.RegKey, false); } catch { }
    }

    public static void RemoveShortcuts() {
      try {
        string desk = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        string sm = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu), "Programs");
        string[] paths = new string[] {
          Path.Combine(desk, AppInfo.Name + ".lnk"),
          Path.Combine(sm, AppInfo.Name + ".lnk"),
          Path.Combine(sm, "卸载 " + AppInfo.Name + ".lnk")
        };
        foreach (string p in paths) { try { if (File.Exists(p)) File.Delete(p); } catch { } }
      } catch { }
    }
  }

  static class AppInfo {
    public const string Name = "PLACEHOLDER_APPNAME";
    public const string Version = "PLACEHOLDER_VERSION";
    public const string RegKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\XZCompressor";
    public const string EulaRaw = "PLACEHOLDER_EULA";
    public static string Eula {
      get { return EulaRaw.Replace("\\n", "\n").Replace("\\t", "\t").Replace("\\\"", "\""); }
    }
  }

  static class Installer {

    [STAThread]
    static void Main() {
      var a = Environment.GetCommandLineArgs();
      bool silent = false, desktop = true, startMenu = true, doUninstall = false;
      string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "XZ压缩工具");
      string uninstallDir = "";
      for (int i = 1; i < a.Length; i++) {
        string x = a[i];
        if (x.Equals("/S", StringComparison.OrdinalIgnoreCase) || x.Equals("/silent", StringComparison.OrdinalIgnoreCase) ||
            x.Equals("/verysilent", StringComparison.OrdinalIgnoreCase) || x.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
            x.Equals("-s", StringComparison.OrdinalIgnoreCase)) silent = true;
        else if (x.StartsWith("/DIR=", StringComparison.OrdinalIgnoreCase)) dir = x.Substring(5);
        else if (x.StartsWith("/D=", StringComparison.OrdinalIgnoreCase)) dir = x.Substring(3);
        else if (x.StartsWith("--dir=", StringComparison.OrdinalIgnoreCase)) dir = x.Substring(6);
        else if (x.Equals("/nodesktop", StringComparison.OrdinalIgnoreCase)) desktop = false;
        else if (x.Equals("/nostartmenu", StringComparison.OrdinalIgnoreCase)) startMenu = false;
        else if (x.Equals("/uninstall", StringComparison.OrdinalIgnoreCase)) { doUninstall = true; }
        else if (x.Equals("/doUninstall", StringComparison.OrdinalIgnoreCase)) {
          if (i + 1 < a.Length) uninstallDir = a[i + 1];
          DoRemoveFiles(uninstallDir);
          return;
        }
        else if (x.Equals("/?") || x.Equals("/h") || x.Equals("--help")) {
          Console.WriteLine(AppInfo.Name + " 安装器\n  /S            静默安装\n  /DIR=目录     指定安装目录\n  /uninstall    卸载\n  /repair       修复\n  /nodesktop    不创建桌面快捷方式\n  /nostartmenu  不创建开始菜单");
          return;
        }
      }

      if (doUninstall) {
        string ud = Core.GetInstallDir();
        if (string.IsNullOrEmpty(ud)) ud = dir;
        BeginUninstall(ud, silent);
        return;
      }

      List<Rec> recs;
      try {
        recs = Core.ReadPayload();
      } catch (Exception ex) {
        if (silent) { Console.Error.WriteLine(ex.Message); Environment.Exit(2); }
        MessageBox.Show("安装数据读取失败：\n" + ex.Message + "\n\n安装包可能已损坏，请重新获取。", AppInfo.Name + " 安装", MessageBoxButtons.OK, MessageBoxIcon.Error);
        return;
      }
      if (recs == null || recs.Count == 0) {
        if (silent) Environment.Exit(2);
        MessageBox.Show("安装数据为空或已损坏。", AppInfo.Name + " 安装", MessageBoxButtons.OK, MessageBoxIcon.Error);
        return;
      }

      if (silent) {
        var r = Core.Install(recs, dir, desktop, startMenu, null);
        if (r.Success) { Console.WriteLine("安装成功: " + dir + " (" + r.Count + " 个文件)"); Environment.Exit(0); }
        else { Console.Error.WriteLine("安装失败: " + r.Error); Environment.Exit(1); }
      }

      Application.EnableVisualStyles();
      Application.SetCompatibleTextRenderingDefault(false);

      // 已安装 -> 维护模式；否则全新安装
      string installed = Core.GetInstallDir();
      if (!string.IsNullOrEmpty(installed) && Directory.Exists(installed)) {
        bool modify = false;
        using (var mf = new MaintenanceForm(recs, installed)) {
          mf.ShowDialog();
          modify = mf.ModifyRequested;
        }
        // "修改安装"：关闭维护窗后再跑向导，绝不嵌套消息循环
        if (modify) Application.Run(new WizardForm(recs, installed));
      } else {
        Application.Run(new WizardForm(recs, null));
      }
    }

    public static void BeginUninstall(string dir, bool silent) {
      if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir)) {
        Core.RemoveReg();
        if (!silent) MessageBox.Show("未找到安装目录，已清理安装记录。", AppInfo.Name + " 卸载", MessageBoxButtons.OK, MessageBoxIcon.Information);
        return;
      }
      if (!silent) {
        DialogResult d = MessageBox.Show("确定要完全卸载 " + AppInfo.Name + " 吗？\n\n安装目录将被删除：\n" + dir + "\n（快捷方式与安装记录也会一并移除）",
          AppInfo.Name + " 卸载", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
        if (d != DialogResult.Yes) return;
      }
      // 复制自身到临时目录，由临时副本完成删除（解除文件占用）
      try {
        string self = Assembly.GetExecutingAssembly().Location;
        string tempCopy = Path.Combine(Path.GetTempPath(), "xzun_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".exe");
        File.Copy(self, tempCopy, true);
        var psi = new ProcessStartInfo(tempCopy);
        psi.Arguments = "/doUninstall \"" + dir + "\"";
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        psi.CreateNoWindow = true;
        psi.UseShellExecute = false;
        Process.Start(psi);
        Environment.Exit(0);
      } catch (Exception ex) {
        if (!silent) MessageBox.Show("卸载启动失败：" + ex.Message, AppInfo.Name + " 卸载", MessageBoxButtons.OK, MessageBoxIcon.Error);
      }
    }

    static void DoRemoveFiles(string dir) {
      // 本进程在临时目录运行，等待主卸载器退出后删除
      Thread.Sleep(900);
      Core.RemoveShortcuts();
      Core.RemoveReg();
      if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir)) {
        for (int t = 0; t < 5; t++) {
          try { Directory.Delete(dir, true); break; }
          catch { Thread.Sleep(600); }
        }
      }
      // 自删除临时副本
      try {
        string self = Assembly.GetExecutingAssembly().Location;
        var psi = new ProcessStartInfo("cmd.exe", "/c ping 127.0.0.1 -n 3 >nul 2>&1 & del /f /q \"" + self + "\"");
        psi.WindowStyle = ProcessWindowStyle.Hidden; psi.CreateNoWindow = true; psi.UseShellExecute = false;
        Process.Start(psi);
      } catch { }
      Environment.Exit(0);
    }
  }

  class MaintenanceForm : Form {
    readonly List<Rec> recs;
    readonly string installDir;
    public bool ModifyRequested;
    public MaintenanceForm(List<Rec> recs, string installDir) {
      this.recs = recs; this.installDir = installDir;
      Text = AppInfo.Name + " 安装维护";
      FormBorderStyle = FormBorderStyle.FixedDialog;
      MaximizeBox = false; MinimizeBox = false;
      StartPosition = FormStartPosition.CenterScreen;
      ClientSize = new Size(460, 230);
      Font = new Font("Microsoft YaHei UI", 9F);
      try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

      var title = new Label { Location = new Point(20, 18), AutoSize = true, Font = new Font("Microsoft YaHei UI", 12F, FontStyle.Bold), ForeColor = Color.FromArgb(30, 60, 110), Text = AppInfo.Name + " 已安装" };
      var path = new Label { Location = new Point(20, 52), Size = new Size(420, 40), ForeColor = Color.FromArgb(60, 60, 60), Text = "安装位置：\n" + installDir };
      path.Text = path.Text.Replace("\n", Environment.NewLine);
      var tip = new Label { Location = new Point(20, 100), AutoSize = true, Text = "请选择要执行的操作：" };

      var btnModify = new Button { Text = "修改安装(M)", Location = new Point(20, 130), Size = new Size(132, 36) };
      var btnRepair = new Button { Text = "修复安装(R)", Location = new Point(164, 130), Size = new Size(132, 36) };
      var btnRemove = new Button { Text = "卸载程序(U)", Location = new Point(308, 130), Size = new Size(132, 36) };
      var btnClose = new Button { Text = "关闭", Location = new Point(164, 178), Size = new Size(132, 36) };

      btnModify.Click += (s, e) => { this.ModifyRequested = true; this.Close(); };
      btnRepair.Click += (s, e) => DoRepair();
      btnRemove.Click += (s, e) => { this.Hide(); Installer.BeginUninstall(installDir, false); this.Close(); };
      btnClose.Click += (s, e) => { this.Close(); };

      Controls.Add(title); Controls.Add(path); Controls.Add(tip);
      Controls.Add(btnModify); Controls.Add(btnRepair); Controls.Add(btnRemove);
      Controls.Add(btnClose);
    }


    void DoRepair() {
      this.Hide();
      using (var f = new RepairForm(recs, installDir)) { f.ShowDialog(); }
      this.Close();
    }
  }

  class RepairForm : Form {
    ProgressBar bar; Label progLabel;
    public RepairForm(List<Rec> recs, string dir) {
      Text = "修复 " + AppInfo.Name;
      FormBorderStyle = FormBorderStyle.FixedDialog;
      MaximizeBox = false; MinimizeBox = false;
      StartPosition = FormStartPosition.CenterScreen;
      ClientSize = new Size(520, 200);
      Font = new Font("Microsoft YaHei UI", 9F);
      try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
      var lab = new Label { Location = new Point(20, 24), AutoSize = true, Text = "正在修复 " + AppInfo.Name + "，重新校验并写入文件……" };
      bar = new ProgressBar { Location = new Point(20, 58), Size = new Size(480, 22), Minimum = 0, Maximum = recs.Count };
      progLabel = new Label { Location = new Point(20, 92), Size = new Size(480, 70) };
      Controls.Add(lab); Controls.Add(bar); Controls.Add(progLabel);
      Load += (s, e) => {
        Application.DoEvents();
        var r = Core.Install(recs, dir, true, true, (name, done) => {
          bar.Value = done; progLabel.Text = "已修复: " + name; Application.DoEvents();
        });
        if (r.Success) {
          MessageBox.Show("修复完成，已重新写入 " + r.Count + " 个文件。", AppInfo.Name + " 修复", MessageBoxButtons.OK, MessageBoxIcon.Information);
          this.Close();
        } else {
          MessageBox.Show("修复失败：" + r.Error, AppInfo.Name + " 修复", MessageBoxButtons.OK, MessageBoxIcon.Error);
          this.Close();
        }
      };
    }
  }

  // 反馈窗口（网络功能模块）
  class FeedbackForm : Form {
    static string ServerUrl = "http://127.0.0.1:14923"; // 部署时改为你的服务器地址
    ComboBox cboType; TextBox txtTitle, txtContent, txtContact;
    public FeedbackForm() {
      Text = AppInfo.Name + " · 用户反馈";
      FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; MinimizeBox = false;
      StartPosition = FormStartPosition.CenterScreen; ClientSize = new Size(440, 360);
      Font = new Font("Microsoft YaHei UI", 9F);
      try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
      Controls.Add(new Label { Location = new Point(16, 14), AutoSize = true, Text = "类型：" });
      cboType = new ComboBox { Location = new Point(100, 10), Width = 160, DropDownStyle = ComboBoxStyle.DropDownList };
      cboType.Items.AddRange(new object[] { "建议", "Bug", "疑问", "其他" }); cboType.SelectedIndex = 0;
      Controls.Add(cboType);
      Controls.Add(new Label { Location = new Point(16, 48), AutoSize = true, Text = "标题：" });
      txtTitle = new TextBox { Location = new Point(100, 44), Width = 320 };
      Controls.Add(txtTitle);
      Controls.Add(new Label { Location = new Point(16, 82), AutoSize = true, Text = "内容：" });
      txtContent = new TextBox { Location = new Point(100, 78), Width = 320, Height = 140, Multiline = true, ScrollBars = ScrollBars.Vertical };
      Controls.Add(txtContent);
      Controls.Add(new Label { Location = new Point(16, 240), AutoSize = true, Text = "联系：" });
      txtContact = new TextBox { Location = new Point(100, 236), Width = 320 };
      Controls.Add(txtContact);
      var btnSend = new Button { Text = "提交反馈", Location = new Point(100, 290), Size = new Size(110, 30) };
      var btnCancel = new Button { Text = "关闭", Location = new Point(230, 290), Size = new Size(110, 30) };
      btnSend.Click += (s, e) => DoSend();
      btnCancel.Click += (s, e) => this.Close();
      Controls.Add(btnSend); Controls.Add(btnCancel);
    }
    void DoSend() {
      if (string.IsNullOrWhiteSpace(txtContent.Text)) { MessageBox.Show("请填写反馈内容。", "提示", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
      try {
        string body = "type=" + Uri.EscapeDataString(cboType.SelectedItem.ToString())
          + "&title=" + Uri.EscapeDataString(txtTitle.Text)
          + "&content=" + Uri.EscapeDataString(txtContent.Text)
          + "&contact=" + Uri.EscapeDataString(txtContact.Text);
        var wc = new WebClient();
        wc.Encoding = Encoding.UTF8;
        wc.Headers[HttpRequestHeader.ContentType] = "application/x-www-form-urlencoded";
        wc.UploadData(ServerUrl + "/xz/feedback", "POST", Encoding.UTF8.GetBytes(body));
        MessageBox.Show("反馈已提交，感谢！", AppInfo.Name, MessageBoxButtons.OK, MessageBoxIcon.Information);
        this.Close();
      } catch (Exception ex) {
        MessageBox.Show("提交失败：" + ex.Message + "\n\n请检查网络后重试。", AppInfo.Name, MessageBoxButtons.OK, MessageBoxIcon.Error);
      }
    }
  }

  class WizardForm : Form {
    readonly List<Rec> recs;
    int step = 0;
    Panel[] pages;
    Button btnBack, btnNext, btnCancel;
    Label headTitle, headDesc;
    TextBox dirBox;
    FolderBrowserDialog fbd;
    CheckBox chkDesktop, chkStartMenu, chkAllUsers, chkRun;
    ProgressBar bar;
    Label progLabel;
    bool installDone = false;
    string installDir, entryPath;

    public WizardForm(List<Rec> recs, string presetDir) {
      this.recs = recs;
      Text = AppInfo.Name + " 安装向导";
      FormBorderStyle = FormBorderStyle.FixedDialog;
      MaximizeBox = false; MinimizeBox = false;
      StartPosition = FormStartPosition.CenterScreen;
      ClientSize = new Size(560, 420);
      Font = new Font("Microsoft YaHei UI", 9F);
      try { this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

      var banner = new Panel { Dock = DockStyle.Top, Height = 64, BackColor = Color.FromArgb(240, 244, 250) };
      var bannerLine = new Label { Dock = DockStyle.Bottom, Height = 1, BackColor = Color.FromArgb(200, 210, 225) };
      headTitle = new Label { Location = new Point(18, 12), AutoSize = true, Font = new Font("Microsoft YaHei UI", 13F, FontStyle.Bold), ForeColor = Color.FromArgb(30, 60, 110) };
      headDesc = new Label { Location = new Point(20, 42), AutoSize = true, ForeColor = Color.FromArgb(70, 70, 70) };
      banner.Controls.Add(headTitle); banner.Controls.Add(headDesc); banner.Controls.Add(bannerLine);

      pages = new Panel[] { BuildWelcome(), BuildLicense(), BuildDir(), BuildProgress(), BuildFinish() };
      foreach (var p in pages) { p.Dock = DockStyle.Fill; p.Padding = new Padding(20, 12, 20, 12); Controls.Add(p); }
      if (!string.IsNullOrEmpty(presetDir)) dirBox.Text = presetDir;

      var bottom = new Panel { Dock = DockStyle.Bottom, Height = 48 };
      var line = new Label { Dock = DockStyle.Top, Height = 1, BackColor = Color.FromArgb(210, 218, 228) };
      btnCancel = new Button { Text = "取消", Size = new Size(82, 28), Location = new Point(466, 10) };
      btnNext = new Button { Text = "下一步(N) >", Size = new Size(100, 28), Location = new Point(356, 10) };
      btnBack = new Button { Text = "< 上一步(B)", Size = new Size(100, 28), Location = new Point(248, 10) };
      btnCancel.Click += (s, e) => { if (installDone) { Close(); return; } if (MessageBox.Show("确定要退出安装吗？", "确认", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes) Close(); };
      btnNext.Click += OnNext;
      btnBack.Click += (s, e) => { if (step > 0) ShowStep(step - 1); };
      bottom.Controls.Add(btnCancel); bottom.Controls.Add(btnNext); bottom.Controls.Add(btnBack); bottom.Controls.Add(line);

      Controls.Add(banner); Controls.Add(bottom);
      ShowStep(0);
    }

    Panel BuildWelcome() {
      var p = new Panel();
      var l = new Label { Location = new Point(20, 30), Size = new Size(500, 240),
        Text = "欢迎使用 " + AppInfo.Name + " 安装向导。\n\n本向导将把 " + AppInfo.Name + " 安装到你的计算机。\n\n" +
               "工具以 xz 极限压缩为主，支持 zip / 7z / gzip / bzip2、\n多形式加密、自解压 EXE / APK、压缩包管理与损坏修复等。\n\n" +
               "本工具源码开源，安装包内文件为明文，安装时直接写入对应位置。\n\n点击“下一步”继续，或“取消”退出安装向导。" };
      l.Text = l.Text.Replace("\n", Environment.NewLine);
      p.Controls.Add(l); return p;
    }

    Panel BuildLicense() {
      var p = new Panel();
      var tb = new TextBox { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
        Location = new Point(20, 16), Size = new Size(500, 210), BackColor = Color.White,
        Text = AppInfo.Eula };
      var agree = new CheckBox { Text = "我已阅读并同意上述说明", Location = new Point(20, 238), AutoSize = true, Checked = true };
      p.Controls.Add(tb); p.Controls.Add(agree); p.Tag = agree;
      return p;
    }

    Panel BuildDir() {
      var p = new Panel();
      var lab = new Label { Location = new Point(20, 24), AutoSize = true, Text = "选择 " + AppInfo.Name + " 的安装位置：" };
      dirBox = new TextBox { Location = new Point(20, 50), Width = 420,
        Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "XZ压缩工具") };
      var browse = new Button { Text = "浏览(R)...", Location = new Point(448, 48), Size = new Size(78, 26) };
      fbd = new FolderBrowserDialog { Description = "选择安装文件夹" };
      browse.Click += (s, e) => { fbd.SelectedPath = dirBox.Text; if (fbd.ShowDialog(this) == DialogResult.OK) dirBox.Text = fbd.SelectedPath; };
      chkDesktop = new CheckBox { Location = new Point(20, 110), AutoSize = true, Text = "在桌面创建快捷方式", Checked = true };
      chkStartMenu = new CheckBox { Location = new Point(20, 140), AutoSize = true, Text = "在开始菜单创建快捷方式", Checked = true };
      chkAllUsers = new CheckBox { Location = new Point(20, 170), AutoSize = true, Text = "为所有用户安装（需要管理员权限）" };
      chkAllUsers.CheckedChanged += (s, e) => {
        if (chkAllUsers.Checked) {
          dirBox.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "XZ压缩工具");
          if (!IsAdmin()) {
            MessageBox.Show("当前不是管理员权限。\n请关闭本安装程序，右键“以管理员身份运行”后再勾选此项。",
              "需要管理员权限", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            chkAllUsers.Checked = false;
            dirBox.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "XZ压缩工具");
          }
        } else {
          dirBox.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "XZ压缩工具");
        }
      };
      var space = new Label { Location = new Point(20, 210), AutoSize = true, ForeColor = Color.Gray, Text = "提示：默认安装到当前用户目录，无需管理员权限。" };
      p.Controls.Add(lab); p.Controls.Add(dirBox); p.Controls.Add(browse);
      p.Controls.Add(chkDesktop); p.Controls.Add(chkStartMenu); p.Controls.Add(chkAllUsers); p.Controls.Add(space);
      return p;
    }

    Panel BuildProgress() {
      var p = new Panel();
      var lab = new Label { Location = new Point(20, 40), AutoSize = true, Text = "正在安装 " + AppInfo.Name + "，请稍候……" };
      bar = new ProgressBar { Location = new Point(20, 76), Size = new Size(500, 22), Minimum = 0, Maximum = recs.Count, Value = 0 };
      progLabel = new Label { Location = new Point(20, 110), Size = new Size(500, 120) };
      p.Controls.Add(lab); p.Controls.Add(bar); p.Controls.Add(progLabel);
      return p;
    }

    Panel BuildFinish() {
      var p = new Panel();
      var l = new Label { Location = new Point(20, 30), Size = new Size(500, 170),
        Text = AppInfo.Name + " 已成功安装。\n\n你可以通过桌面或开始菜单快捷方式启动。\n网络功能（公告 / 投票 / 反馈入口）已一并安装，\n安装目录下有“网络功能说明.txt”和“查看公告.url”。\n\n以后再次运行本安装程序，可进行“修改 / 修复 / 卸载”。" };
      l.Text = l.Text.Replace("\n", Environment.NewLine);
      chkRun = new CheckBox { Location = new Point(20, 210), AutoSize = true, Text = "安装完成后立即启动 " + AppInfo.Name, Checked = false };
      p.Controls.Add(l); p.Controls.Add(chkRun);
      return p;
    }

    void ShowStep(int i) {
      step = i; pages[i].BringToFront();
      switch (i) {
        case 0: headTitle.Text = "欢迎"; headDesc.Text = AppInfo.Name + " 安装向导"; break;
        case 1: headTitle.Text = "许可说明"; headDesc.Text = "请阅读使用说明"; break;
        case 2: headTitle.Text = "安装位置"; headDesc.Text = "选择安装目录"; break;
        case 3: headTitle.Text = "正在安装"; headDesc.Text = "写入文件"; break;
        case 4: headTitle.Text = "完成"; headDesc.Text = "安装已完成"; break;
      }
      btnBack.Enabled = (i > 0 && i < 3);
      btnNext.Enabled = (i != 3);
      btnNext.Text = (i == 4) ? "完成(F)" : (i == 2 ? "安装(I)" : "下一步(N) >");
    }

    void OnNext(object s, EventArgs e) {
      if (step == 1) {
        var agree = pages[1].Tag as CheckBox;
        if (!agree.Checked) { MessageBox.Show("请先同意使用说明后再继续。", AppInfo.Name + " 安装", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
      }
      if (step == 2) {
        installDir = dirBox.Text.Trim();
        if (string.IsNullOrEmpty(installDir)) { MessageBox.Show("请选择安装目录。", "提示", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
        ShowStep(3); Application.DoEvents(); RunInstall(); return;
      }
      if (step == 4) {
        InstallNetworkFeats(installDir);
        if (chkRun != null && chkRun.Checked && !string.IsNullOrEmpty(entryPath)) TryRun();
        Close(); return;
      }
      ShowStep(step + 1);
    }

    void RunInstall() {
      var log = new StringBuilder();
      int total = recs.Count;
      var r = Core.Install(recs, installDir, chkDesktop.Checked, chkStartMenu.Checked, (name, done) => {
        bar.Maximum = total; bar.Value = done;
        log.AppendLine("已写入: " + name);
        progLabel.Text = log.ToString();
        Application.DoEvents();
      });
      if (r.Success) { entryPath = r.Entry; installDone = true; ShowStep(4); }
      else { MessageBox.Show("安装失败：\n" + r.Error, AppInfo.Name + " 安装", MessageBoxButtons.OK, MessageBoxIcon.Error); ShowStep(2); }
    }

    void TryRun() {
      try {
        var psi = new ProcessStartInfo(entryPath) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(entryPath) };
        Process.Start(psi);
      } catch { }
    }

    static bool IsAdmin() {
      try {
        using (var id = System.Security.Principal.WindowsIdentity.GetCurrent()) {
          var prin = new System.Security.Principal.WindowsPrincipal(id);
          return prin.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
        }
      } catch { return false; }
    }

    static void InstallNetworkFeats(string dir) {
      try {
        if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir)) return;
        // 公告 / 投票 / 反馈入口说明
        string baseUrl = "http://127.0.0.1:14923"; // 部署时改为你的服务器地址
        string readme = Path.Combine(dir, "网络功能说明.txt");
        File.WriteAllText(readme,
          "XZ 压缩工具 · 网络功能" + Environment.NewLine +
          "====================================" + Environment.NewLine +
          "公告地址：" + baseUrl + "/xz/announce" + Environment.NewLine +
          "投票接口：" + baseUrl + "/xz/polls" + Environment.NewLine +
          "管理后台：" + baseUrl + "/admin" + Environment.NewLine +
          "反馈入口：在主菜单工具集里选择“用户反馈”，或再次运行本安装程序选择“修改安装”。" + Environment.NewLine,
          Encoding.UTF8);
        // 公告快捷方式
        string url = Path.Combine(dir, "查看公告.url");
        File.WriteAllText(url, "[InternetShortcut]\r\nURL=" + baseUrl + "/xz/announce\r\n", Encoding.Default);
      } catch { }
    }
  }


}
