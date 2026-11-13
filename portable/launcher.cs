using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class PortableLauncher
{
    static void Main(string[] args)
    {
        try { Console.OutputEncoding = System.Text.Encoding.UTF8; } catch { }
        string dir = Path.Combine(Path.GetTempPath(), "xzport_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        try
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            string[] names = asm.GetManifestResourceNames();
            if (names.Length == 0)
            {
                Console.WriteLine("[错误] 便携包内未找到任何文件, 请重新生成。");
                Console.ReadKey();
                return;
            }
            foreach (string n in names)
            {
                string fname = Path.GetFileName(n);
                using (Stream rs = asm.GetManifestResourceStream(n))
                using (FileStream fs = File.Create(Path.Combine(dir, fname)))
                    rs.CopyTo(fs);
            }
            ProcessStartInfo psi = new ProcessStartInfo("cmd", "/k title XZ便携压缩工具 & cd /d \"" + dir + "\" & xzport.cmd");
            psi.UseShellExecute = false;
            Process p = Process.Start(psi);
            p.WaitForExit();
        }
        catch (Exception ex)
        {
            Console.WriteLine("[错误] " + ex.Message);
            Console.WriteLine("按任意键退出...");
            Console.ReadKey();
        }
        finally
        {
            try { Directory.Delete(dir, true); } catch { }
        }
    }
}
